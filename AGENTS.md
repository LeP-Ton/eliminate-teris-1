# 项目认知记录

## 2026-02-14
- 项目通过 `run.sh` 启动可执行程序，当前策略已改为“每次启动前强制重新编译”，避免启动到旧构建产物。
- `run.sh` 会优先使用 `/Applications/Xcode.app/Contents/Developer` 作为 `DEVELOPER_DIR`（若用户未手动设置）。
- 启动路径通过 `swift build --show-bin-path` 计算，避免手写架构目录导致路径偏差。
