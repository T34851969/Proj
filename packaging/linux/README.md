# Linux 打包(deb / rpm / 客户端三件套)

## 服务器包(deb / rpm)

内容物 = `build_release.sh` 的自包含布局(内嵌 standalone CPython),目标机零依赖。

```bash
# 1) 构建布局(需 backend/.venv 与 client/dist;venv 必须用 standalone CPython,见下红线)
backend/scripts/build_release.sh --stage /tmp/layout

# 2) 打 deb(本机只需 dpkg-deb,无需 debian 环境)
packaging/linux/build-deb.sh --layout /tmp/layout/ai-resume-server-linux-x86_64-lite --version X.Y.Z --out dist-release

# 3) 打 rpm(本机只需 rpmbuild;ubuntu 上 apt install rpm 即可,无需红帽环境)
packaging/linux/build-rpm.sh --layout /tmp/layout/ai-resume-server-linux-x86_64-lite --version X.Y.Z --out dist-release
```

- **安装行为**: enable 不 start(团队规则);启动: `systemctl enable --now ai-resume`
- `.env` 是 conffile / `%config(noreplace)`,升级不覆盖用户配置
- 包内容: `/opt/ai-resume`(布局) + `/usr/lib/systemd/system/ai-resume.service` + 系统用户 `ai-resume`
- rpm 已关 AutoReqProv(内嵌解释器会生成伪依赖)

## 客户端包(deb / rpm / AppImage, Tauri)

`npx tauri build --bundles deb,rpm,appimage`(CI `client-linux` job 自动做;构建机需要
libwebkit2gtk-4.1-dev 等,见 workflow)。与 Windows 桌面端同一份产品代码。

## 构建与验证矩阵

| 包 | 构建地 | 真机验证 |
| --- | --- | --- |
| 服务器 deb | x99(nix-shell 取 dpkg)/ CI ubuntu | Debian 12 验证机(x99 KVM,常驻) |
| 服务器 rpm | x99(nix-shell 取 rpm)/ CI ubuntu | Fedora 44 验证机(x99 KVM,常驻) |
| 客户端 deb/rpm/AppImage | CI ubuntu(Tauri) | 发版后人工验收 |

## 运行时选型红线

布局里的 runtime **必须**来自 standalone CPython(python-build-standalone,glibc 2.17 起)。
发行版自带或 nix 构建的 CPython 拷入布局后,在目标发行版必坏(glibc 版本耦合,
nix 解释器还会拖出 libstdc++/site-packages 的连锁问题)。
x99 侧 standalone 解释器: `/data/toolchains/python-3.11.18/`。
