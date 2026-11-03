<template>
  <div class="resume-edit">
    <div
      v-for="module in orderedModules"
      :key="module.key"
      class="module-wrapper"
      :class="{ 'is-drag-over': dragOverModule === module.key }"
      @dragenter.prevent="onModuleDragEnter(module.key)"
      @dragover.prevent="onModuleDragOver(module.key, $event)"
      @dragleave="onModuleDragLeave(module.key)"
      @drop="onModuleDrop(module.key, $event)"
    >
      <a-dropdown :trigger="['click']">
        <button
          class="module-drag-handle"
          type="button"
          draggable="true"
          :aria-label="`调整${module.label}模块顺序`"
          @dragstart="onModuleDragStart(module.key, $event)"
          @dragend="onModuleDragEnd"
        >
          <MenuOutlined />
        </button>
        <template #overlay>
          <a-menu @click="(info: any) => onMenuClick(info, module.key)">
            <a-menu-item key="up" :disabled="isFirstModule(module.key)">
              <arrow-up-outlined /> 上移
            </a-menu-item>
            <a-menu-item key="down" :disabled="isLastModule(module.key)">
              <arrow-down-outlined /> 下移
            </a-menu-item>
            <a-menu-item key="bottom" :disabled="isLastModule(module.key)">
              <vertical-align-bottom-outlined /> 置底
            </a-menu-item>
          </a-menu>
        </template>
      </a-dropdown>
      <component :is="module.component" />
    </div>

    <div
      v-show="draggingModule"
      class="module-drop-zone"
      @dragenter.prevent
      @dragover.prevent
      @drop="onDropToEnd"
    >
      <MenuOutlined />
      <span>拖到这里可将模块放到最后</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type { Component } from 'vue';
import { MenuOutlined, ArrowUpOutlined, ArrowDownOutlined, VerticalAlignBottomOutlined } from '@ant-design/icons-vue';
import { useResumeStore } from '../../../store';
import type { SectionKey } from '../../../types/resume';
import { sectionLabels } from '../../../constants/sectionLabels';
import personalInfo from './personalInfo.vue';
import education from './education.vue';
import workExperience from './workExperience.vue';
import skill from './skill.vue';
import honor from './honor.vue';
import selfEvaluation from './selfEvaluation.vue';
import project from './project.vue';

type ModuleDefinition = {
  key: SectionKey;
  label: string;
  component: Component;
};

const moduleDefinitions: ModuleDefinition[] = [
  { key: 'personalInfo', label: sectionLabels.personalInfo, component: personalInfo },
  { key: 'education', label: sectionLabels.education, component: education },
  { key: 'projects', label: sectionLabels.projects, component: project },
  { key: 'workExperience', label: sectionLabels.workExperience, component: workExperience },
  { key: 'skills', label: sectionLabels.skills, component: skill },
  { key: 'honors', label: sectionLabels.honors, component: honor },
  { key: 'summary', label: sectionLabels.summary, component: selfEvaluation }
];

const moduleMap = new Map<SectionKey, ModuleDefinition>(
  moduleDefinitions.map(definition => [definition.key, definition])
);

const resumeStore = useResumeStore();

// 统一持久化:编辑页所有分区组件共享一个订阅(原先 6 个组件各自 deep watcher,
// 每敲一个字触发 6 次全量 JSON.stringify + localStorage 写入)
resumeStore.$subscribe(() => {
  resumeStore.saveToLocalStorage();
});

const orderedModules = computed(() =>
  resumeStore.sectionOrder
    .map(key => moduleMap.get(key))
    .filter((module): module is ModuleDefinition => Boolean(module))
);

const draggingModule = ref<SectionKey | null>(null);
const dragOverModule = ref<SectionKey | null>(null);

const onModuleDragStart = (key: SectionKey, event: DragEvent) => {
  draggingModule.value = key;
  dragOverModule.value = null;
  event.dataTransfer?.setData('text/plain', key);
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move';
  }
};

const onModuleDragEnd = () => {
  draggingModule.value = null;
  dragOverModule.value = null;
};

const onModuleDragEnter = (key: SectionKey) => {
  if (!draggingModule.value || draggingModule.value === key) return;
  dragOverModule.value = key;
};

const onModuleDragLeave = (key: SectionKey) => {
  if (dragOverModule.value === key) {
    dragOverModule.value = null;
  }
};

const onModuleDragOver = (key: SectionKey, event: DragEvent) => {
  if (!draggingModule.value) return;
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move';
  }
  if (dragOverModule.value !== key && draggingModule.value !== key) {
    dragOverModule.value = key;
  }
};

const onModuleDrop = (key: SectionKey, event: DragEvent) => {
  event.preventDefault();
  if (!draggingModule.value) return;

  const currentTarget = event.currentTarget as HTMLElement | null;
  let placement: 'before' | 'after' = 'before';

  if (currentTarget) {
    const rect = currentTarget.getBoundingClientRect();
    if (event.clientY - rect.top > rect.height / 2) {
      placement = 'after';
    }
  }

  resumeStore.moveSection(draggingModule.value, key, placement);
  draggingModule.value = null;
  dragOverModule.value = null;
};

const onDropToEnd = (event: DragEvent) => {
  event.preventDefault();
  if (!draggingModule.value) return;

  const nextOrder = resumeStore.sectionOrder.filter(item => item !== draggingModule.value);
  nextOrder.push(draggingModule.value);
  resumeStore.setSectionOrder(nextOrder);

  draggingModule.value = null;
  dragOverModule.value = null;
};

// ---- 把手菜单:触摸设备无法拖拽时的排序入口(桌面同样可用) ----
const isFirstModule = (key: SectionKey) => resumeStore.sectionOrder[0] === key;
const isLastModule = (key: SectionKey) =>
  resumeStore.sectionOrder[resumeStore.sectionOrder.length - 1] === key;

const onHandleMenuClick = (action: string, key: SectionKey) => {
  const order = [...resumeStore.sectionOrder];
  const index = order.indexOf(key);
  if (index < 0) return;

  if (action === 'bottom') {
    order.splice(index, 1);
    order.push(key);
  } else {
    const target = action === 'up' ? index - 1 : index + 1;
    if (target < 0 || target >= order.length) return;
    [order[index], order[target]] = [order[target], order[index]];
  }
  resumeStore.setSectionOrder(order);
};

const onMenuClick = ({ key }: { key: string | number }, moduleKey: SectionKey) => {
  onHandleMenuClick(String(key), moduleKey);
};
</script>

<style scoped>
.resume-edit {
  padding: 12px;
  height: 100vh;
  overflow-y: auto;
  scrollbar-width: thin;
}

.module-wrapper {
  position: relative;
  padding-left: 28px;
  margin-bottom: 16px;
  border-radius: 10px;
  background: var(--panel-surface);
  border: 1px solid var(--border-color);
  box-shadow: none;
}

.module-wrapper.is-drag-over {
  outline: 2px dashed var(--primary-color);
  border-color: rgba(111, 147, 189, 0.32);
}

.module-drag-handle {
  position: absolute;
  left: 0;
  top: 12px;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  border: none;
  background: transparent;
  color: var(--text-muted);
  padding: 0;
}

.module-drag-handle:active {
  cursor: grabbing;
}

.module-drop-zone {
  margin-top: 12px;
  padding: 12px;
  border: 1px dashed var(--border-color);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--text-muted);
  font-size: 12px;
  background: var(--panel-surface);
}

.module-drop-zone svg {
  font-size: 16px;
}

@media (max-width: 768px) {
  .resume-edit {
    height: 100%;
    padding: 10px;
  }

  .module-wrapper {
    padding: 34px 8px 8px;
    margin-bottom: 12px;
    border-radius: 8px;
  }

  .module-drag-handle {
    left: 10px;
    top: 8px;
    width: 30px;
    height: 30px;
  }

  .module-drop-zone {
    margin-bottom: 12px;
  }

  :deep(.ant-collapse-content-box) {
    padding: 12px;
  }
}
</style>
