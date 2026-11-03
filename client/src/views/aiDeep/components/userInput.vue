<script lang="ts" setup>
import { inject, type Ref, ref, computed } from "vue";
import { message } from "ant-design-vue";
import { useResumeStore } from "../../../store";
import { toRef } from "vue";
import { useChatPresets } from "../../../composables/useChatPresets";
const resume = toRef(useResumeStore());

interface ExperienceOption {
  label: string;
  value: string;
}
// 构建经历的选项
const experienceOptions: ExperienceOption[] = []
const selectedExperience = ref<string>();
// 项目经历
resume.value.projects.forEach((item) => (
  experienceOptions.push({
    label: '项目:' + item.projectName,
    value: '项目简介：' + item.briefIntroduction + '\n项目描述：' + item.description,
  })));
// 工作经历
resume.value.workExperience.forEach((item) => (
  experienceOptions.push({
    label: '工作:' + item.company,
    value: '公司名称：' + item.company + '\n职位：' + item.position + '\n工作内容：' + item.description,
  })));
const jd = inject<Ref<string>>("jd");
const resumeProject = inject<Ref<string>>("resumeProject");
const handleExperienceChange = (value: string) => {
  if (resumeProject) {
    resumeProject.value = value;
  }
};

// ---- 预设档案 ----
const { presets, save, remove } = useChatPresets();
const activePresetId = ref<string | null>(null);
const saveOpen = ref(false);
const saveName = ref("");

const presetOptions = computed(() =>
  presets.value.map((p) => ({ label: p.name, value: p.id }))
);

function applyPreset(id: string) {
  const preset = presets.value.find((p) => p.id === id);
  if (!preset || !jd || !resumeProject) return;
  jd.value = preset.jd;
  resumeProject.value = preset.experience;
  activePresetId.value = id;
  message.success(`已应用预设「${preset.name}」`);
}

function openSave() {
  saveName.value = "";
  saveOpen.value = true;
}

function confirmSave() {
  if (!jd?.value && !resumeProject?.value) {
    message.warning("JD 与经历都为空,没有可保存的内容");
    return;
  }
  const preset = save(saveName.value, jd?.value ?? "", resumeProject?.value ?? "");
  activePresetId.value = preset.id;
  saveOpen.value = false;
  message.success(`已保存预设「${preset.name}」`);
}

function removeCurrent() {
  if (!activePresetId.value) return;
  remove(activePresetId.value);
  activePresetId.value = null;
  message.success("预设已删除");
}
</script>

<template>
  <div class="data-input">
    <!-- 预设档案管理 -->
    <div class="preset-section">
      <div class="input-header">
        预设档案
        <span style="font-size: 12px; font-weight: normal;">（像简历档案一样保存常用的岗位组合）</span>
      </div>
      <div class="preset-row">
        <a-select
          :value="undefined"
          placeholder="加载已保存的预设…"
          :options="presetOptions"
          class="preset-select"
          @change="(v: any) => applyPreset(String(v))"
        />
        <a-button size="small" @click="openSave">存为预设</a-button>
        <a-button v-if="activePresetId" size="small" danger ghost @click="removeCurrent">删除当前</a-button>
      </div>
    </div>

    <div class="input-section">
      <div class="input-header">岗位 JD<span style="font-size: 12px;">（岗位要求）</span></div>
      <a-textarea v-model:value="jd" placeholder="请输入岗位 JD..." class="custom-textarea" />
    </div>
    <!-- 选项框-用户可以选择一段经历来进行问答 -->
    <div class="select-section">
      <div class="input-header">选择经历<span style="font-size: 12px;">（选择一段经历拷打）</span></div>
      <a-select v-model:value="selectedExperience" placeholder="请选择经历" :options="experienceOptions"
        @change="handleExperienceChange" />
    </div>
    <div class="input-section" id="input-value">
      <div class="input-header">经历<span style="font-size: 12px;">（建议一次深挖一段经历即可）</span></div>
      <a-textarea v-model:value="resumeProject" placeholder="请输入项目/实习/工作经历..." class="custom-textarea" />
    </div>

    <!-- 存为预设弹窗 -->
    <a-modal v-model:open="saveOpen" title="存为预设档案" ok-text="保存" cancel-text="取消" @ok="confirmSave">
      <a-input v-model:value="saveName" placeholder="预设名称，如：字节前端-秋招" :maxlength="30" />
    </a-modal>
  </div>
</template>

<style scoped>
.data-input {
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 20px;
  background: var(--bg-card-color);
}

.preset-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.preset-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.preset-select {
  flex: 1;
  min-width: 0;
}

.select-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 0;
}

.input-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 0;
}
</style>
