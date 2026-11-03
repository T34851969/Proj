/**
 * AI 深度交流的"岗位/经历"预设档案(本机存储)。
 * 类似简历档案的用法:把常用的 岗位JD + 经历 组合命名保存,一键换装。
 */
import { ref } from 'vue';

export interface ChatPreset {
  id: string;
  name: string;
  jd: string;        // 岗位 JD
  experience: string; // 经历(一段)
}

const LS_KEY = 'chatPresets';

function load(): ChatPreset[] {
  try {
    const raw = localStorage.getItem(LS_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function persist(items: ChatPreset[]) {
  localStorage.setItem(LS_KEY, JSON.stringify(items));
}

const presets = ref<ChatPreset[]>(load());

export function useChatPresets() {
  const save = (name: string, jd: string, experience: string): ChatPreset => {
    const preset: ChatPreset = {
      id: `cp-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`,
      name: name.trim() || `预设 ${presets.value.length + 1}`,
      jd,
      experience
    };
    presets.value = [...presets.value, preset];
    persist(presets.value);
    return preset;
  };

  const remove = (id: string) => {
    presets.value = presets.value.filter((p) => p.id !== id);
    persist(presets.value);
  };

  return { presets, save, remove };
}
