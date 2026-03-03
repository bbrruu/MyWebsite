---
title: "記帳 APP"
description: "個人記帳行動應用程式，支援收支分類、圖表統計與歷史紀錄查詢。以 React Native + Expo 開發，可部署為 Web 版。"
pubDate: 2026-03-03
status: "Active"
techStack: ["React Native", "Expo", "TypeScript", "AsyncStorage"]
demoUrl: "https://budgetapp-amber.vercel.app/"
githubUrl: "https://github.com/bbrruu/budgetapp"
featured: true
category: "App"
---

## 簡介

以 React Native + Expo 開發的個人記帳 APP，資料儲存於本機，完全離線可用，並透過 Expo Web 部署為瀏覽器版本。

## 功能

- **收支記錄**：支援 8 種支出類別（飲食、交通、娛樂⋯）與 5 種收入類別
- **統計圖表**：圓餅圖（類別佔比）、折線圖（每日趨勢）、柱狀圖（月份比較）
- **月份篩選**：可切換查看各月的收支歷史紀錄
- **本機儲存**：以 AsyncStorage 持久化資料，無需帳號登入

## 技術細節

- React Native + TypeScript，同時支援 iOS / Android / Web（Expo）
- `@react-navigation/bottom-tabs` 管理頁面導航
- `react-native-chart-kit` + `react-native-svg` 渲染各類統計圖表
- AsyncStorage 作為本機資料庫，讀寫收支紀錄
- 透過 `npx expo export --platform web` 產生靜態網頁，部署至 Vercel
