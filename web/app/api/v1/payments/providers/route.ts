import { NextResponse } from "next/server";
import { isInternalPaymentAllowed } from "@/lib/api/payment-checkout";

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function configuredProvider() {
  return cleanText(process.env.PAYMENT_PROVIDER).toLowerCase();
}

function hasExternalCheckout() {
  return cleanText(process.env.PAYMENT_CHECKOUT_ENDPOINT).length > 0;
}

function providerEnabled(ids: string[]) {
  const provider = configuredProvider();
  return hasExternalCheckout() && ids.includes(provider);
}

export async function GET() {
  const provider = configuredProvider();
  const externalCheckout = hasExternalCheckout();
  const providers = [
    {
      id: "wechat_pay",
      label: "微信支付",
      channel: "wallet",
      enabled: providerEnabled(["wechat", "wechat_pay", "wechatpay"]),
    },
    {
      id: "alipay",
      label: "支付宝",
      channel: "wallet",
      enabled: providerEnabled(["alipay", "ali_pay"]),
    },
    {
      id: "bank_card",
      label: "银行卡",
      channel: "card",
      enabled: providerEnabled(["stripe", "bank_card", "card"]),
    },
    {
      id: "internal",
      label: "内部测试支付",
      channel: "test",
      enabled: isInternalPaymentAllowed(),
      test: true,
    },
  ];

  return NextResponse.json({
    success: true,
    data: {
      checkout_mode: externalCheckout ? "external" : "internal",
      configured_provider: provider || null,
      providers,
    },
  });
}
