#!/usr/bin/env node

import { createHash, createHmac } from "node:crypto";
import { createReadStream, statSync } from "node:fs";
import https from "node:https";
import path from "node:path";
import process from "node:process";
import { config as loadEnv } from "dotenv";

loadEnv({ path: path.resolve(".env"), quiet: true });

const [, , sourceArgument, keyArgument, ...flags] = process.argv;
const overwrite = flags.includes("--overwrite");

if (!sourceArgument || !keyArgument) {
  console.error(
    "用法: node scripts/upload-curated-cos-asset.mjs <本地文件> <COS 对象路径> [--overwrite]",
  );
  process.exit(2);
}

const sourcePath = path.resolve(sourceArgument);
const objectKey = keyArgument.replace(/^\/+/, "");
if (!/^[a-zA-Z0-9][a-zA-Z0-9._/-]*$/.test(objectKey) || objectKey.includes("..")) {
  console.error("COS 对象路径不安全，已停止上传。");
  process.exit(2);
}

const file = statSync(sourcePath);
if (!file.isFile()) {
  console.error("上传来源不是普通文件。");
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
const requestPath = `/${objectKey
  .split("/")
  .map(encodeURIComponent)
  .join("/")}`;

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
    requestPath,
    "",
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
    "q-url-param-list=",
    `q-signature=${signature}`,
  ].join("&");
}

function request({ method, headers = {}, bodyPath }) {
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
        path: requestPath,
        headers: {
          ...signedHeaders,
          Authorization: authorize(method, signedHeaders),
          ...(bodyPath ? { "Content-Length": file.size } : {}),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () =>
          resolve({
            status: res.statusCode ?? 0,
            headers: res.headers,
            body: Buffer.concat(chunks).toString("utf8"),
          }),
        );
      },
    );
    req.on("error", reject);
    if (bodyPath) {
      createReadStream(bodyPath).on("error", reject).pipe(req);
    } else {
      req.end();
    }
  });
}

const existing = await request({ method: "HEAD" });
if (existing.status === 200 && !overwrite) {
  console.error(`COS 对象已存在，未覆盖: ${objectKey}`);
  process.exit(3);
}
if (![200, 404].includes(existing.status)) {
  console.error(`无法检查 COS 对象（HTTP ${existing.status}），已停止上传。`);
  process.exit(4);
}

const extension = path.extname(sourcePath).toLowerCase();
const contentType =
  extension === ".html"
    ? "text/html; charset=utf-8"
    : extension === ".txt"
      ? "text/plain; charset=utf-8"
      : "application/octet-stream";
const sha256 = createHash("sha256");
for await (const chunk of createReadStream(sourcePath)) sha256.update(chunk);
const digest = sha256.digest("hex");

console.log(
  `正在上传 ${path.basename(sourcePath)}（${(file.size / 1024 / 1024).toFixed(1)} MB）`,
);
const uploaded = await request({
  method: "PUT",
  bodyPath: sourcePath,
  headers: {
    "content-type": contentType,
    "x-cos-acl": "public-read",
    "x-cos-meta-sha256": digest,
  },
});
if (![200, 201].includes(uploaded.status)) {
  console.error(`COS 上传失败（HTTP ${uploaded.status}）。`);
  process.exit(5);
}

const verified = await request({ method: "HEAD" });
if (verified.status !== 200) {
  console.error(`上传后验证失败（HTTP ${verified.status}）。`);
  process.exit(6);
}
if (
  Number(verified.headers["content-length"]) !== file.size ||
  verified.headers["x-cos-meta-sha256"] !== digest
) {
  console.error("上传后文件大小或 SHA-256 校验不一致。");
  process.exit(7);
}

console.log(`上传并校验完成: https://${host}${requestPath}`);
console.log(`SHA-256: ${digest}`);
