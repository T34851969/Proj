<template>
  <div class="me-container">
    <a-card class="me-card" :bordered="false">
      <h2 class="title">我的</h2>
      <div class="connection-status" :class="health.status.value">
        <span class="status-dot" />
        <span class="status-text">{{ statusText }}</span>
        <a-button v-if="health.status.value === 'down'" size="small" @click="health.refresh()">重试</a-button>
      </div>
      <AccountPanel />
      <ConnectionPanel />
      <AiModelPanel />
      <ThemePanel />
      <p class="tips">
        大模型调用相关的 API Key、API URL、模型名称等配置由服务端统一管理。
      </p>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import AccountPanel from '../../components/settings/AccountPanel.vue';
import ConnectionPanel from '../../components/settings/ConnectionPanel.vue';
import ThemePanel from '../../components/settings/ThemePanel.vue';
import AiModelPanel from '../../components/settings/AiModelPanel.vue';
import { useBackendHealth } from '../../composables/useBackendHealth';
import { getServerBase } from '../../utils/auth';

const health = useBackendHealth();
const statusText = computed(() => {
  if (health.status.value === 'ok') {
    const base = getServerBase();
    return base ? `服务端已连接(${base.replace(/^https?:\/\//, '')})` : '服务端已连接';
  }
  if (health.status.value === 'down') return '服务端离线,请在下方检查服务端地址';
  return '正在检测服务端…';
});
</script>

<style scoped>
.me-container {
  display: flex;
  justify-content: center;
  padding: 24px 16px calc(24px + env(safe-area-inset-bottom));
  min-height: calc(100vh - 72px);
}

.me-card {
  width: 100%;
  max-width: 640px;
  background: var(--bg-card-color);
  border-radius: 16px;
  box-shadow: 0 16px 40px var(--shadow-color);
  border: 1px solid var(--border-color);
  padding: 24px;
  height: fit-content;
}

.title {
  font-size: 22px;
  font-weight: bold;
  margin-bottom: 16px;
  color: var(--text-color);
}

.connection-status {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--border-color);
  border-radius: 10px;
  background: var(--inset-bg);
  margin-bottom: 20px;
  font-size: 13px;
  color: var(--text-color);
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--text-muted);
  flex-shrink: 0;
}

.connection-status.ok .status-dot {
  background: #52c41a;
}

.connection-status.down .status-dot {
  background: #ff4d4f;
}

.status-text {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tips {
  font-size: 13px;
  background: rgba(60, 80, 120, 0.08);
  padding: 12px;
  border-radius: 8px;
  color: var(--text-muted);
  line-height: 1.5;
  text-align: justify;
  border: 1px solid var(--border-color);
  margin: 0;
}

@media (max-width: 768px) {
  .me-container {
    padding: 12px 12px calc(24px + env(safe-area-inset-bottom));
  }

  .me-card {
    padding: 16px;
    border-radius: 14px;
  }

  .title {
    font-size: 19px;
    margin-bottom: 12px;
  }
}
</style>
