<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { theme } from 'ant-design-vue';
import Header from "./components/Header/index.vue";
import { useResumeStore } from './store/useResumeStore';
import { useProfileStore } from './store/useProfileStore';
import { useSettingsStore } from './store/useSettingsStore';
import { useBackendHealth } from './composables/useBackendHealth';

const settingsStore = useSettingsStore();
const profileStore = useProfileStore();
const { start: startHealthPolling } = useBackendHealth();

// 页面加载时初始化
onMounted(async () => {
  const resumeStore = useResumeStore();
  await resumeStore.initCheck();
  settingsStore.initTheme();
  startHealthPolling();
  await profileStore.ensureReady();
});

const antdThemeConfig = computed(() => ({
  algorithm: settingsStore.isDark ? theme.darkAlgorithm : theme.defaultAlgorithm,
  token: {
    colorPrimary: settingsStore.theme,
    borderRadius: 8,
  },
}));
</script>

<template>
  <a-config-provider :theme="antdThemeConfig">
    <div class="app-shell">
      <Header />
      <main class="app-content">
        <router-view v-slot="{ Component }">
          <transition name="page-fade" mode="out-in">
            <keep-alive include="aiDeep">
              <component :is="Component" />
            </keep-alive>
          </transition>
        </router-view>
      </main>
    </div>
  </a-config-provider>
</template>

<style scoped>
.app-shell {
  min-height: 100vh;
}

.app-content {
  min-height: calc(100vh - 72px);
}

@media (max-width: 768px) {
  .app-content {
    min-height: 100svh;
    /* viewport-fit=cover 后内容延伸进状态栏,顶部补偿安全区 */
    padding-top: env(safe-area-inset-top);
    padding-bottom: calc(76px + env(safe-area-inset-bottom));
  }
}
</style>

<style>
/* 路由切换过渡:轻位移+淡入(移动端观感平滑) */
.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}

.page-fade-enter-from {
  opacity: 0;
  transform: translateY(8px);
}

.page-fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}

/* 触摸按下反馈(移动端轻缩放) */
@media (max-width: 768px) {
  .ant-btn:not(:disabled):active {
    transform: scale(0.97);
  }
}
</style>
