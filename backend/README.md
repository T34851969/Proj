# backend — FastAPI 服务端

> 本文只给三条命令。部署/数据/配置/排障见 [../OPS.md](../OPS.md)；接口契约见 [../backend-api.md](../backend-api.md)。

## 安装

```bash
cd backend
python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt   # Windows: .venv\Scripts\pip
```

## 运行

```bash
./run.sh                    # 自激活 .venv，默认 127.0.0.1:8000
PORT=9000 ./run.sh          # 改端口
```

> 生产/发行包内为单 uvicorn 实例：阻塞操作已全部进线程池，单进程即可承载并发；多进程会重复加载嵌入模型且与 SQLite 单写者语义不匹配，**不要**使用 `--workers`。

## 测试

```bash
.venv/bin/python -m pytest  # testpaths=tests，96 例
```

## 指向

| 需要什么 | 去哪 |
| --- | --- |
| 部署、升级、数据目录、`.env` 全量变量、排障 | [../OPS.md](../OPS.md) |
| 接口契约（请求/响应） | [../backend-api.md](../backend-api.md) |
| 打包成 deb/rpm/发行包 | [../packaging/README.md](../packaging/README.md) |
