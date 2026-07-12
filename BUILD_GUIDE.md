# Xlist 安卓 APK 云端编译指南

> 用 GitHub Actions 免费编译，手机浏览器即可操作。

---

## 一、Fork 项目

1. 手机浏览器打开 https://github.com/xlist-io/xlist
2. 点右上角 **Fork** → 选你的账号 → 确认
3. 等几秒，你的账号下就有一份 `xlist` 仓库了

---

## 二、添加编译配置

Fork 后的仓库里还没有 `.github/workflows/build-apk.yml`，需要手动添加。

### 方法 A：手机浏览器直接操作（推荐）

1. 打开你 Fork 后的仓库页面
2. 点进 `.github/workflows/` 目录（没有就创建）
3. 点 **Add file** → **Create new file**
4. 文件名填：`build-apk.yml`
5. 把下面的内容粘贴进去（就是本项目里 `.github/workflows/build-apk.yml` 的内容）
6. 点 **Commit changes**

### 方法 B：电脑上操作

```bash
# 克隆你 Fork 的仓库
git clone https://github.com/你的用户名/xlist.git
cd xlist

# workflow 文件已经包含在项目里，直接推送即可
git add .github/workflows/build-apk.yml
git commit -m "ci: add APK build workflow"
git push
```

---

## 三、触发编译

### 手动触发（推荐）

1. 手机浏览器打开你的仓库
2. 点 **Actions** 标签页
3. 左侧选 **Build Android APK**
4. 点右侧 **Run workflow** 按钮
5. 选 `release`（正式版）或 `debug`（调试版）
6. 绿色的 **Run workflow** 确认

### 自动触发

推送到 `master` 分支时会自动编译。

---

## 四、下载 APK

编译大约需要 **15-25 分钟**。

1. 进入 **Actions** → 点击正在进行（或已完成）的构建任务
2. 等待所有步骤变成绿色 ✅
3. 页面最下方 **Artifacts** 区域 → 点击 APK 文件名下载
4. 传到手机上安装即可

> ⚠️ Artifacts 30 天后过期，及时下载。

---

## 五、打 Tag 自动发布 Release（可选）

如果想生成正式的发布版本：

```bash
git tag v1.0.0
git push origin v1.0.0
```

Actions 会自动构建并创建 GitHub Release，APK 会附在 Release 页面。

---

## 六、常见问题

### Q: 构建失败了怎么办？

- 进 Actions 点击失败的构建 → 展开红色的步骤 → 看错误日志
- 常见原因：依赖下载超时（重试即可）、Flutter 版本不兼容

### Q: 怎么更新 Flutter 版本？

编辑 `.github/workflows/build-apk.yml`，修改这行：
```yaml
flutter-version: '3.22.2'  # 改成你需要的版本
```

### Q: 免费额度够用吗？

GitHub Actions 免费用户每月 **2000 分钟**（公开仓库不计费）。
一次 APK 构建约 20 分钟，公开仓库可以无限次构建。

### Q: APK 安装时提示"未知来源"？

正常。去手机 **设置 → 安全 → 允许安装未知来源应用**，然后重新安装。

### Q: 我改了代码怎么重新编译？

推送到 master 分支就会自动触发：
```bash
git add .
git commit -m "your changes"
git push
```
或者去 Actions 页面手动 Run workflow。
