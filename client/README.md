# client — Vue 前端与 Tauri 壳

> 本文只给四条命令。部署/数据/配置见 [../OPS.md](../OPS.md)；路由与接口见 [../API.md](../API.md)。

构建产物为纯静态文件，运行时由后端 FastAPI 直接托管（单端口 8000），不需要 Node、不需要 nginx。

## 安装

```bash
cd client
npm ci
```

## 运行

```bash
npm run dev                 # http://localhost:5173，/api 代理到 127.0.0.1:8000
```

## 测试

```bash
npm run test                # vitest，16 例
npm run build               # vue-tsc 严格类型检查 + 生产构建 → dist/
```

## 指向

| 需要什么 | 去哪 |
| --- | --- |
| 部署、数据目录、`.env`、排障 | [../OPS.md](../OPS.md) |
| 路由与接口契约 | [../API.md](../API.md) |
| 桌面端/APK 打包 | [../packaging/README.md](../packaging/README.md) |
