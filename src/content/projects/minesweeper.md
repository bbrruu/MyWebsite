---
title: "踩地雷"
description: "經典踩地雷遊戲，支援三種難度與自訂盤面，附計時器與最佳成績紀錄。React + TypeScript 實作，嵌入 Astro 靜態網站。"
pubDate: 2026-02-26
status: "Active"
techStack: ["React", "TypeScript", "Astro"]
demoUrl: "/minesweeper"
coverImage: "/images/minesweeper-cover.svg"
featured: true
category: "App"
---

## 簡介

在個人網站上直接玩踩地雷！這是嵌入 Astro 靜態網站的第一個互動作品，使用 React + TypeScript 開發，透過 Astro 的 React Integration 掛載。

## 功能

- 三種難度：初級（9×9/10雷）、中級（16×16/40雷）、高級（16×30/99雷）
- 自訂盤面：自行輸入行列數與地雷數
- 計時器與最佳成績（localStorage 儲存）
- 第一次點擊保證安全（不會踩到地雷）
- 桌機右鍵插旗、手機長按插旗、插旗模式切換按鈕

## 技術細節

- `useGameState` hook 封裝所有遊戲邏輯
- BFS 洪水填充自動展開空白區域
- 第一次點擊後才隨機放置地雷，排除首格及其 8 鄰格
