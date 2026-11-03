import type { Template } from '../types/template';
import { getServerBase } from './auth';

let bundledCache: Template[] | null = null;

async function getBundled(): Promise<Template[]> {
  if (bundledCache === null) {
    try {
      const response = await fetch('/templates.json');
      bundledCache = response.ok ? await response.json() : [];
    } catch {
      bundledCache = [];
    }
  }
  return bundledCache ?? [];
}

/**
 * 模板列表:优先取服务端分发(运营改 data/templates.json 即时同步),
 * 服务端不可用/为空时回退到随客户端打包的列表(离线桌面端可用)。
 */
export const getTemplates = async (): Promise<Template[]> => {
  const base = getServerBase();
  if (base) {
    try {
      const response = await fetch(`${base}/api/templates`);
      if (response.ok) {
        const list = await response.json();
        if (Array.isArray(list) && list.length > 0) return list;
      }
    } catch { /* 回退打包列表 */ }
  }
  return getBundled();
};
