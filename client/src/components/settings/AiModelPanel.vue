<template>
  <div class="input-group">
    <label>AI 模型</label>
    <a-radio-group :value="mode" button-style="solid" @change="(e: any) => setMode(e.target.value)">
      <a-radio-button value="server">跟随服务器（需登录）</a-radio-button>
      <a-radio-button value="custom">自带 Key</a-radio-button>
    </a-radio-group>

    <template v-if="mode === 'custom'">
      <a-input v-model:value="cfg.apiUrl" placeholder="API URL,如 https://api.deepseek.com/v1/chat/completions" addon-before="API URL" />
      <a-input-password v-model:value="cfg.apiKey" placeholder="API Key(仅本机保存,请求时经服务器转发,不落库)" addon-before="API Key" />
      <a-input v-model:value="cfg.model" placeholder="模型名,如 deepseek-chat / qwen-plus" addon-before="模型" />
      <p class="field-tip">
        自带 Key 模式:简历生成与 AI 对话使用你填的模型;Key 只存在本机浏览器,
        调用时随请求经服务器转发并即刻丢弃,服务端不存储。
      </p>
    </template>
    <template v-else>
      <p class="field-tip">
        使用服务端统一配置的模型(运营者在「智能体 → 模型服务」中管理);该模式需登录账号。
      </p>
    </template>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue';

const LS_MODE = 'aiModelMode';
const LS_CFG = 'aiCustomLlm';

const mode = ref<'server' | 'custom'>('server');
const cfg = reactive({ apiUrl: '', apiKey: '', model: '' });

function setMode(v: 'server' | 'custom') {
  mode.value = v;
  if (v === 'server') {
    localStorage.removeItem(LS_CFG);
  } else {
    localStorage.setItem(LS_CFG, JSON.stringify(cfg));
  }
}

onMounted(() => {
  const savedMode = localStorage.getItem(LS_MODE);
  if (savedMode === 'custom' || savedMode === 'server') mode.value = savedMode;
  try {
    const saved = JSON.parse(localStorage.getItem(LS_CFG) || 'null');
    if (saved) Object.assign(cfg, saved);
  } catch { /* ignore */ }
});

watch(cfg, () => {
  if (mode.value === 'custom') {
    localStorage.setItem(LS_CFG, JSON.stringify(cfg));
  }
}, { deep: true });
</script>

<style scoped>
.input-group {
  margin-bottom: 24px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.field-tip {
  font-size: 12px;
  color: var(--text-muted);
  margin: 0;
  line-height: 1.6;
}

label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 4px;
  color: var(--text-color);
}
</style>
