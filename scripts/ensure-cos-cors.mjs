#!/usr/bin/env node

import { createHash, createHmac } from "node:crypto";
import https from "node:https";
import path from "node:path";
import process from "node:process";
import { config as loadEnv } from "dotenv";

loadEnv({ path: path.resolve(".env"), quiet: true });

const allowedOrigin = process.argv[2]?.trim();
const ruleId = process.argv[3]?.trim() || "artiqore-immersive-viewer";
if (!allowedOrigin || !/^https?:\/\/[^/]+$/.test(allowedOrigin)) {
  console.error(
    "用法: node scripts/ensure-cos-cors.mjs <允许的 Origin> [规则 ID]",
  );
  process.exit(2);
}

const secretId = process.env.TENCENT_CLOUD_SECRET_ID?.trim();
const secretKey = process.env.TENCENT_CLOUD_SECRET_KEY?.trim();
const securityToken = process.env.TENCENT_CLOUD_SECURITY_TOKEN?.trim();
const bucket = process.env.TENCENT_COS_BUCKET?.trim();
const region =
  process.env.TENCENT_COS_REGION?.trim() ||
  process.env.TENCENT_CLOUD_REGION?.trim();
const missing = [
  !secretId && "TENCENT_CLOUD_SECRET_ID",
  !secretKey && "TENCENT_CLOUD_SECRET_KEY",
  !bucket && "TENCENT_COS_BUCKET",
  !region && "TENCENT_COS_REGION",
].filter(Boolean);
if (missing.length > 0) {
  console.error(`缺少腾讯 COS 配置: ${missing.join(", ")}`);
  process.exit(2);
}

const host = `${bucket}.cos.${region}.myqcloud.com`;
const sha1 = (value) =>
  createHash("sha1").update(value, "utf8").digest("hex");
const hmacSha1 = (key, value) =>
  createHmac("sha1", key).update(value, "utf8").digest("hex");

function authorize(method, headers) {
  const now = Math.floor(Date.now() / 1000);
  const keyTime = `${now};${now + 15 * 60}`;
  const signedHeaders = Object.fromEntries(
    Object.entries(headers).map(([name, value]) => [
      name.toLowerCase(),
      String(value).trim(),
    ]),
  );
  const headerNames = Object.keys(signedHeaders).sort();
  const headerList = headerNames.join(";");
  const formattedHeaders = headerNames
    .map(
      (name) =>
        `${encodeURIComponent(name)}=${encodeURIComponent(signedHeaders[name])}`,
    )
    .join("&");
  const httpString = [
    method.toLowerCase(),
    "/",
    "cors=",
    formattedHeaders,
    "",
  ].join("\n");
  const stringToSign = ["sha1", keyTime, sha1(httpString), ""].join("\n");
  const signingKey = hmacSha1(secretKey, keyTime);
  const signature = hmacSha1(signingKey, stringToSign);
  return [
    "q-sign-algorithm=sha1",
    `q-ak=${secretId}`,
    `q-sign-time=${keyTime}`,
    `q-key-time=${keyTime}`,
    `q-header-list=${headerList}`,
    "q-url-param-list=cors",
    `q-signature=${signature}`,
  ].join("&");
}

function cosRequest({ method, body = "", headers = {} }) {
  return new Promise((resolve, reject) => {
    const signedHeaders = {
      host,
      ...headers,
      ...(securityToken ? { "x-cos-security-token": securityToken } : {}),
    };
    const req = https.request(
      {
        hostname: host,
        method,
        path: "/?cors",
        headers: {
          ...signedHeaders,
          Authorization: authorize(method, signedHeaders),
          ...(body ? { "Content-Length": Buffer.byteLength(body) } : {}),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () =>
          resolve({
            status: res.statusCode ?? 0,
            body: Buffer.concat(chunks).toString("utf8"),
          }),
        );
      },
    );
    req.on("error", reject);
    req.end(body || undefined);
  });
}

const current = await cosRequest({ method: "GET" });
const hasNoConfig =
  current.status === 404 &&
  (current.body.includes("NoSuchCORSConfiguration") || !current.body);
if (current.status !== 200 && !hasNoConfig) {
  console.error(`读取 COS CORS 配置失败（HTTP ${current.status}）。`);
  process.exit(3);
}

const escapeXml = (value) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
const rule = [
  "<CORSRule>",
  `<ID>${escapeXml(ruleId)}</ID>`,
  `<AllowedOrigin>${escapeXml(allowedOrigin)}</AllowedOrigin>`,
  "<AllowedMethod>GET</AllowedMethod>",
  "<AllowedMethod>HEAD</AllowedMethod>",
  "<AllowedMethod>PUT</AllowedMethod>",
  "<AllowedHeader>Authorization</AllowedHeader>",
  "<AllowedHeader>Content-Type</AllowedHeader>",
  "<AllowedHeader>Range</AllowedHeader>",
  "<AllowedHeader>x-cos-acl</AllowedHeader>",
  "<AllowedHeader>x-cos-meta-upload-id</AllowedHeader>",
  "<AllowedHeader>x-cos-meta-expected-size</AllowedHeader>",
  "<AllowedHeader>x-cos-server-side-encryption</AllowedHeader>",
  "<AllowedHeader>x-cos-security-token</AllowedHeader>",
  "<ExposeHeader>ETag</ExposeHeader>",
  "<ExposeHeader>Accept-Ranges</ExposeHeader>",
  "<ExposeHeader>Content-Length</ExposeHeader>",
  "<ExposeHeader>Content-Range</ExposeHeader>",
  "<ExposeHeader>x-cos-meta-sha256</ExposeHeader>",
  "<ExposeHeader>x-cos-hash-crc64ecma</ExposeHeader>",
  "<ExposeHeader>x-cos-request-id</ExposeHeader>",
  "<MaxAgeSeconds>600</MaxAgeSeconds>",
  "</CORSRule>",
].join("");

const existingRule = hasNoConfig
  ? null
  : (current.body.match(/<CORSRule>[\s\S]*?<\/CORSRule>/g) || []).find(
      (candidate) => candidate.includes(`<ID>${escapeXml(ruleId)}</ID>`),
    );
if (existingRule === rule) {
  console.log(`COS CORS 规则已是最新: ${ruleId}`);
  process.exit(0);
}

const xml = hasNoConfig
  ? `<?xml version="1.0" encoding="UTF-8"?><CORSConfiguration>${rule}</CORSConfiguration>`
  : existingRule
    ? current.body.replace(existingRule, rule)
    : current.body.replace("</CORSConfiguration>", `${rule}</CORSConfiguration>`);
if (!xml.includes(`<ID>${ruleId}</ID>`)) {
  console.error("无法安全合并 COS CORS 配置，已停止。");
  process.exit(4);
}

const contentMd5 = createHash("md5").update(xml, "utf8").digest("base64");
const updated = await cosRequest({
  method: "PUT",
  body: xml,
  headers: {
    "content-md5": contentMd5,
    "content-type": "application/xml",
  },
});
if (updated.status !== 200) {
  console.error(`更新 COS CORS 配置失败（HTTP ${updated.status}）。`);
  process.exit(5);
}

const verified = await cosRequest({ method: "GET" });
if (
  verified.status !== 200 ||
  !verified.body.includes(`<ID>${ruleId}</ID>`) ||
  !verified.body.includes(`<AllowedOrigin>${allowedOrigin}</AllowedOrigin>`) ||
  !verified.body.includes("<AllowedMethod>PUT</AllowedMethod>")
) {
  console.error("COS CORS 规则写入后验证失败。");
  process.exit(6);
}

console.log(`COS CORS 规则已写入并验证: ${ruleId} → ${allowedOrigin}`);
