/**
 * 统一的文件保存出口。
 * - 浏览器:<a download> 触发下载
 * - Tauri 桌面端:WebView2 不处理 <a download>(点击无反应),
 *   走原生保存对话框(dialog 插件)+ 写文件(fs 插件)
 */
import { isTauriEnv } from './auth';

export async function saveBlob(blob: Blob, filename: string): Promise<boolean> {
  if (!isTauriEnv()) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
    return true;
  }

  try {
    const { save } = await import('@tauri-apps/plugin-dialog');
    const { writeFile } = await import('@tauri-apps/plugin-fs');
    const path = await save({ defaultPath: filename });
    if (!path) return false; // 用户取消
    await writeFile(path, new Uint8Array(await blob.arrayBuffer()));
    return true;
  } catch (error) {
    console.error('保存文件失败', error);
    return false;
  }
}
