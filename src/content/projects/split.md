---
title: "出遊分帳"
description: "記錄每筆帳目與各人金額，自動以最少交易筆數計算結清方案。支援自訂金額分攤，資料存於 localStorage。"
pubDate: 2026-03-02
status: "Active"
techStack: ["React", "TypeScript", "Astro"]
demoUrl: "/split"
featured: true
category: "Tool"
---

## 簡介

出遊後常常搞不清楚誰要給誰多少錢？這個工具讓你記錄每筆帳目與各人應付金額，並自動計算出**最少交易筆數**的結清方案。

## 功能

- 三步驟引導：設定成員 → 記錄帳目 → 結算
- 每筆帳目支援自訂各人分攤金額（不限等額）
- 一鍵平均分攤快捷按鈕
- 以貪婪演算法計算最少交易筆數
- 資料自動存於 localStorage，重新整理不遺失
- 複製結算清單純文字功能
- 清空重置（含確認對話框）

## 技術細節

- `useSplitState` hook 封裝所有狀態、localStorage 同步與結算計算
- 結算演算法：計算每人淨餘額後，以 greedy 方式配對最大債主與最大債務人
- React + TypeScript 實作，嵌入 Astro 靜態網站
