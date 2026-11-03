<script setup lang="ts">
import { ref, provide } from "vue";
import { SettingOutlined } from '@ant-design/icons-vue';
import userInput from './components/userInput.vue';
import AIChat from './components/AIChat.vue';
import { useIsMobile } from '../../composables/useIsMobile';

//子组件之间通信 jd 以及 简历数据
const resumeProject = ref<string>("");
const jd = ref<string>("");

defineOptions({
  name: "aiDeep"  // keep-alive需要
});

provide("resumeProject", resumeProject);
provide("jd", jd);

// 移动端:聊天优先,配置收进抽屉
const { isMobile } = useIsMobile();
const configOpen = ref(false);
</script>

<template>
  <!-- 单根包裹:路由过渡(transition)要求单根组件,多根会在页面切换时卡死白屏 -->
  <div class="aideep-page">
    <!-- 移动端:配置入口(聊天区右上角由本栏提供) -->
    <div v-if="isMobile" class="mobile-config-bar">
      <span class="mobile-config-title">AI 深度交流</span>
      <a-button size="small" @click="configOpen = true">
        <setting-outlined />
        岗位与经历
      </a-button>
    </div>

    <div class="main-box">
      <div class="left">
        <AIChat />
      </div>
      <div v-if="!isMobile" class="right">
        <userInput />
      </div>
    </div>

    <!-- 移动端配置抽屉 -->
    <a-drawer
      v-model:open="configOpen"
      title="岗位与经历配置"
      placement="right"
      :width="320"
      root-class-name="aideep-config-drawer"
    >
      <userInput v-if="configOpen" />
    </a-drawer>
  </div>
</template>

<style scoped>
.aideep-page {
  min-height: 100%;
}

.mobile-config-bar {
  display: none;
}

@media (max-width: 768px) {
  .mobile-config-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
  }

  .mobile-config-title {
    font-weight: 600;
    color: var(--text-color);
  }

  .main-box {
    max-width: none;
    width: auto;
    height: auto;
    min-height: calc(100svh - 220px);
    margin: 0 8px;
  }
}
</style>

<style scoped>
.main-box {
  border-radius: 24px;
  background: var(--panel-gradient);
  margin: 30px auto;
  box-shadow: var(--panel-shadow);
  border: 1px solid var(--border-color);
  padding: 5px;
  display: flex;
  max-width: 80vw;
  height: 85vh;
}

.left {
  flex: 1;
  padding: 10px;
  border-right: 1px solid var(--border-color);
}

.right {
  /* display: flex;
  flex-direction: column; */
  width: 30%;
  min-width: 250px;
}

@media (max-width: 768px) {
  .main-box {
    display: flex;
    flex-direction: column;
    max-width: none;
    width: auto;
    height: auto;
    min-height: 0;
    margin: 12px;
    padding: 0;
    border-radius: 16px;
    overflow: hidden;
  }

  .left,
  .right {
    width: 100%;
    min-width: 0;
    padding: 0;
  }

  .left {
    order: 2;
    min-height: 560px;
    border-right: 0;
    border-top: 1px solid var(--border-color);
  }

  .right {
    order: 1;
  }
}
</style>
