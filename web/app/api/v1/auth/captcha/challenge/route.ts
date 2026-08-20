import { randomBytes } from "crypto";
import { NextRequest, NextResponse } from "next/server";

import {
  getTencentCaptchaChallengeConfig,
  TencentCaptchaConfigError,
} from "@/lib/api/tencent-captcha";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function allowedReturnOrigin(request: NextRequest) {
  const requested = request.nextUrl.searchParams.get("return_origin");
  if (!requested) return null;
  let origin: string;
  try {
    origin = new URL(requested).origin;
  } catch {
    return null;
  }
  const allowed = new Set(
    (process.env.TENCENT_CAPTCHA_ALLOWED_ORIGINS ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean)
      .map((value) => {
        try {
          return new URL(value).origin;
        } catch {
          return "";
        }
      })
      .filter(Boolean)
  );
  allowed.add(request.nextUrl.origin);
  if (process.env.NODE_ENV !== "production") {
    const hostname = new URL(origin).hostname;
    if (hostname === "localhost" || hostname === "127.0.0.1") return origin;
  }
  return allowed.has(origin) ? origin : null;
}

function htmlResponse(
  html: string,
  nonce: string,
  frameAncestor: string | null,
  status = 200
) {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store, max-age=0",
      "Content-Security-Policy": [
        "default-src 'self' https: data: blob:",
        `script-src 'nonce-${nonce}' https://turing.captcha.qcloud.com`,
        "style-src 'unsafe-inline' https:",
        "object-src 'none'",
        "base-uri 'none'",
        "form-action 'none'",
        `frame-ancestors ${frameAncestor ?? "'none'"}`,
      ].join("; "),
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
      "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    },
  });
}

export async function GET(request: NextRequest) {
  const nonce = randomBytes(18).toString("base64");
  let captchaConfig: ReturnType<typeof getTencentCaptchaChallengeConfig>;
  try {
    captchaConfig = getTencentCaptchaChallengeConfig();
  } catch (error) {
    if (error instanceof TencentCaptchaConfigError) {
      return NextResponse.json(
        { success: false, error: "安全验证服务暂不可用" },
        {
          status: 503,
          headers: { "Cache-Control": "no-store" },
        }
      );
    }
    throw error;
  }
  const returnOrigin = allowedReturnOrigin(request);
  const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>艺见心安全验证</title>
  <style>
    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f6f7f8; color: #202428; }
    main { width: min(86vw, 360px); text-align: center; }
    .mark { width: 44px; height: 44px; margin: 0 auto 18px; border-radius: 50%; display: grid; place-items: center; background: #202428; color: white; font-size: 22px; }
    h1 { margin: 0 0 8px; font-size: 20px; }
    p { margin: 0 0 20px; color: #687078; font-size: 14px; line-height: 1.6; }
    button { border: 0; border-radius: 999px; padding: 12px 24px; background: #202428; color: white; font: inherit; cursor: pointer; }
    button:disabled { opacity: .5; cursor: wait; }
  </style>
</head>
<body>
  <main>
    <div class="mark" aria-hidden="true">✓</div>
    <h1>发送短信前请完成验证</h1>
    <p id="status" role="status">正在加载安全验证…</p>
    <button id="retry" type="button" hidden>重新验证</button>
  </main>
  <script nonce="${nonce}">
    (() => {
      const appId = ${JSON.stringify(captchaConfig.appId)};
      const aidEncrypted = ${JSON.stringify(captchaConfig.aidEncrypted)};
      const returnOrigin = ${JSON.stringify(returnOrigin)};
      const status = document.getElementById('status');
      const retry = document.getElementById('retry');
      let captcha = null;

      function deliver(result, payload = {}) {
        const message = JSON.stringify({
          type: 'artsee.tencent-captcha',
          result,
          ...payload,
        });
        if (window.parent !== window && returnOrigin) {
          window.parent.postMessage(message, returnOrigin);
          return;
        }
        if (window.opener && !window.opener.closed && returnOrigin) {
          window.opener.postMessage(message, returnOrigin);
          window.setTimeout(() => window.close(), 80);
          return;
        }
        const query = new URLSearchParams(payload).toString();
        window.location.href = 'artsee-captcha://' + result + (query ? '?' + query : '');
      }

      function showError(message) {
        status.textContent = message;
        retry.hidden = false;
        retry.disabled = false;
      }

      function callback(res) {
        if (res && res.ret === 0 && res.ticket && res.randstr && !res.errorCode) {
          deliver('success', { ticket: String(res.ticket), randstr: String(res.randstr) });
        } else if (res && res.ret === 2) {
          deliver('cancel');
        } else {
          showError('安全验证未通过，请重试');
        }
      }

      function showCaptcha() {
        retry.hidden = true;
        retry.disabled = true;
        status.textContent = '正在加载安全验证…';
        try {
          captcha = new TencentCaptcha(appId, callback, {
            userLanguage: 'zh-cn',
            enableDarkMode: true,
            aidEncrypted,
            aidEncryptedType: 'gcm',
          });
          captcha.show();
        } catch (_) {
          showError('安全验证加载失败，请检查网络后重试');
        }
      }

      retry.addEventListener('click', showCaptcha);
      const script = document.createElement('script');
      script.src = 'https://turing.captcha.qcloud.com/TJCaptcha.js';
      script.async = true;
      script.onload = showCaptcha;
      script.onerror = () => showError('安全验证加载失败，请检查网络后重试');
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>`;
  return htmlResponse(html, nonce, returnOrigin);
}
