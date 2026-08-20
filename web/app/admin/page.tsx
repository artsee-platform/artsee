"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  ArrowRight,
  BarChart3,
  BadgeCheck,
  BookOpenCheck,
  Banknote,
  ClipboardList,
  FileCheck2,
  IdCard,
  Landmark,
  ListChecks,
  LogIn,
  LogOut,
  MessageSquareWarning,
  PlugZap,
  ReceiptText,
  RotateCcw,
  ShieldCheck,
  UsersRound,
} from "lucide-react";

const ADMIN_LINKS = [
  {
    href: "/admin/integrations",
    title: "第三方集成自检",
    description: "脱敏检查凭证、数据库迁移、控制台配置和冒烟验收状态。",
    icon: PlugZap,
  },
  {
    href: "/admin/dashboard",
    title: "数据看板",
    description: "查看用户、内容、咨询和交易核心指标。",
    icon: BarChart3,
  },
  {
    href: "/admin/mentor-withdrawals",
    title: "导师提现审核",
    description: "审核提现申请，标记通过、拒绝或已打款。",
    icon: Banknote,
  },
  {
    href: "/admin/payout-batches",
    title: "打款批次",
    description: "将已通过提现打包成批次，统一处理打款状态。",
    icon: Landmark,
  },
  {
    href: "/admin/refunds",
    title: "退款申请",
    description: "处理订单退款申请，跟踪退款处理结果。",
    icon: RotateCcw,
  },
  {
    href: "/admin/reconciliation",
    title: "支付对账",
    description: "导入支付、退款和打款结算文件，自动核销匹配记录。",
    icon: ReceiptText,
  },
  {
    href: "/admin/ledger",
    title: "资金流水",
    description: "查看订单入账、平台服务费、导师收益、退款和打款流水。",
    icon: BookOpenCheck,
  },
  {
    href: "/admin/audit-logs",
    title: "操作审计",
    description: "查看管理员高风险操作、资金处理和对账导入记录。",
    icon: ListChecks,
  },
  {
    href: "/admin/content",
    title: "内容审核",
    description: "集中审核活动、机会、作品和艺术家档案。",
    icon: FileCheck2,
  },
  {
    href: "/admin/verifications",
    title: "身份认证审核",
    description: "审核学生、艺术家、收藏者和机构入驻申请。",
    icon: IdCard,
  },
  {
    href: "/admin/reports",
    title: "举报中心",
    description: "处理用户举报、标记处理中或完结，并保留审计记录。",
    icon: MessageSquareWarning,
  },
  {
    href: "/admin/users",
    title: "用户管理",
    description: "查看用户画像，调整角色与运营状态。",
    icon: UsersRound,
  },
  {
    href: "/admin/consultations",
    title: "咨询管理",
    description: "查看平台咨询线索和会话状态。",
    icon: ClipboardList,
  },
  {
    href: "/admin/mentors",
    title: "导师认证审核",
    description: "审核独立导师申请，控制导师主页展示。",
    icon: BadgeCheck,
  },
];

function hasAdminToken() {
  if (typeof window === "undefined") return false;
  return Boolean(
    localStorage.getItem("artiqore_access_token") ||
      localStorage.getItem("access_token")
  );
}

export default function AdminHomePage() {
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    setSignedIn(hasAdminToken());
  }, []);

  function logout() {
    localStorage.removeItem("artiqore_access_token");
    localStorage.removeItem("access_token");
    setSignedIn(false);
    window.location.href = "/admin/login";
  }

  return (
    <div className="min-h-screen bg-[#f7f5ef] px-5 py-6 text-[#1a1a1a] md:px-8">
      <div className="mx-auto flex max-w-6xl flex-col gap-6">
        <header className="flex flex-col gap-4 border-b border-black/10 pb-5 md:flex-row md:items-center md:justify-between">
          <div>
            <div className="mb-2 inline-flex items-center gap-2 rounded-full bg-white px-3 py-1 text-xs font-bold text-[#003399] ring-1 ring-black/10">
              <ShieldCheck size={14} />
              Artiqore Admin
            </div>
            <h1 className="text-2xl font-black tracking-normal md:text-3xl">运营后台</h1>
            <p className="mt-2 max-w-2xl text-sm font-medium leading-6 text-black/56">
              用于处理平台审核、资金状态和高风险运营操作。请使用管理员账号登录后访问各模块。
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            {signedIn ? (
              <button
                type="button"
                onClick={logout}
                className="inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-black/10 bg-white px-4 text-sm font-bold text-black/70 hover:border-[#d90429]/30 hover:text-[#d90429]"
              >
                <LogOut size={16} />
                退出后台
              </button>
            ) : (
              <Link
                href="/admin/login"
                className="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-[#003399] px-4 text-sm font-bold text-white hover:bg-[#002a80]"
              >
                <LogIn size={16} />
                管理员登录
              </Link>
            )}
            <Link
              href="/"
              className="inline-flex h-10 items-center justify-center rounded-lg border border-black/10 bg-white px-4 text-sm font-bold text-black/70 hover:border-[#003399]/30 hover:text-[#003399]"
            >
              返回前台
            </Link>
          </div>
        </header>

        <section className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {ADMIN_LINKS.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className="group rounded-lg border border-black/10 bg-white p-4 shadow-sm transition hover:border-[#003399]/30 hover:shadow-md"
              >
                <div className="mb-4 flex items-start justify-between gap-3">
                  <span className="inline-flex h-10 w-10 items-center justify-center rounded-lg bg-[#003399]/8 text-[#003399]">
                    <Icon size={19} />
                  </span>
                  <ArrowRight
                    size={17}
                    className="text-black/28 transition group-hover:translate-x-0.5 group-hover:text-[#003399]"
                  />
                </div>
                <h2 className="text-base font-black">{item.title}</h2>
                <p className="mt-2 text-sm font-medium leading-6 text-black/52">{item.description}</p>
              </Link>
            );
          })}
        </section>
      </div>
    </div>
  );
}
