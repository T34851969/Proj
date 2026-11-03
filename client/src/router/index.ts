import { createRouter, createWebHistory, type RouteRecordRaw } from "vue-router";
import { getSessionUser } from "@/utils/auth";

const routes: Array<RouteRecordRaw> = [
  {
    path: "/",
    name: "resume",
    component: () => import("@/views/resume/index.vue"),
    meta: { title: "AI简历 - 简历制作" }
  },
  {
    path: "/template",
    name: "template",
    component: () => import("@/views/template/index.vue"),
    meta: { title: "AI简历 - 模板市场" }
  },
  {
    path: "/agent",
    name: "agent",
    component: () => import("@/views/agent/index.vue"),
    meta: { title: "AI简历 - 智能体工作台" }
  },
  {
    path: "/setting",
    name: "setting",
    component: () => import("@/views/setting/index.vue"),
    meta: { title: "AI简历 - 网站配置" }
  },
  {
    path: "/me",
    name: "me",
    component: () => import("@/views/me/index.vue"),
    meta: { title: "AI简历 - 我的" }
  },
  {
    path: "/admin",
    name: "admin",
    component: () => import("@/views/admin/index.vue"),
    meta: { title: "AI简历 - 运营后台" }
  },
  {
    path: "/aiDeep",
    name: "aiDeep",
    component: () => import("@/views/aiDeep/index.vue"),
    meta: { title: "AI简历 - AI深度交流", keepAlive: true }
  },
  {
    path: "/auth",
    name: "auth",
    component: () => import("@/views/auth/index.vue"),
    meta: { title: "AI简历 - 注册/登录" }
  },
  {
    path: "/:pathMatch(.*)*",
    name: "NotFound",
    component: () => import("../views/404.vue")
  }
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
});

// 路由守卫:默认允许匿名浏览(不强制登录贴脸),登录入口在「我的」页;
// 仅运营后台要求 admin。服务端 required 模式下接口 401 由拦截器引导。
router.beforeEach((to) => {
  if (to.name === "admin" && getSessionUser()?.role !== "admin") {
    return { name: "auth", query: { redirect: to.fullPath } };
  }
  return true;
});

router.afterEach((to) => {
  document.title = (to.meta?.title as string) || "AI简历";
});

export default router;
