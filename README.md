# VoiceBridgeAI

## 功能

- FastAPI 服务
- 静态页面入口
- `GET /api/health` 健康检查
- 浏览器标签页音频捕获（Chrome，需勾选「分享标签页音频」）

## 快速启动

在项目根目录执行：

```bash
chmod +x run.sh && ./run.sh
```

另开终端验证：

```bash
curl http://127.0.0.1:8765/api/health
```

浏览器访问：<http://127.0.0.1:8765>

## 手动启动

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd server && python main.py
```

若终端已在 `server/` 目录，直接运行 `python main.py` 即可。
