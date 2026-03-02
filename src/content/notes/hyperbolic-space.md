---
title: "雙曲語義空間的數學原理"
description: "從雙曲幾何到 WordNet 語意距離：龐加萊圓盤、Möbius 加法、測地線、LCA 與 Wu-Palmer 相似度的完整推導。"
pubDate: 2026-02-27
tags: ["雙曲幾何", "NLP", "WordNet", "計算語言學"]
category: "NLP"
demoUrl: "/hyperbolic"
---

## 為什麼要用雙曲空間？

語言的語意關係本質上是**樹狀的**：「貴賓犬」是「狗」的下位詞，「狗」是「哺乳類」的下位詞，「哺乳類」是「動物」的下位詞……這種上下位關係（hypernym/hyponym）形成一棵層次樹。

然而，如果試著把這棵樹塞進二維歐氏平面，會遇到一個根本困難：**節點數量以指數增長，但歐氏空間的面積只以多項式增長**。深度 d 的樹若每個節點有 b 個子節點，葉節點有 b^d 個；但歐氏圓盤半徑 r 的面積只有 πr²。空間根本不夠用。

**雙曲空間恰好相反**：其面積以指數方式擴張。雙曲圓盤半徑 r 的面積約為 π(e^r − 1)²——層級越深，可用空間越多，完美匹配樹的結構。

<figure>
  <img src="/images/hyperbolic/heptagonal-tiling.svg" alt="七邊形雙曲鑲嵌" />
  <figcaption>七邊形雙曲鑲嵌（Heptagonal tiling）。在雙曲平面中，每向外一層的格子數量以指數增長，圖案越靠近邊界越密集——這正是雙曲幾何「容量大」的直觀體現。<br/>來源：Wikimedia Commons, CC BY-SA</figcaption>
</figure>

---

## 龐加萊圓盤（Poincaré Disk）

龐加萊圓盤是雙曲幾何的一個模型，由法國數學家 Henri Poincaré 在 19 世紀末提出。

**定義**：龐加萊圓盤是半徑為 1 的開放單位圓盤

> **D** = { (x, y) ∈ ℝ² | x² + y² < 1 }

搭配特殊的雙曲度量。這個模型的關鍵性質：

- **邊界圓（x² + y² = 1）代表無窮遠**——節點越靠近邊界，在雙曲空間中離原點越「遠」
- **原點代表根節點**，是整個樹的中心
- **從原點到邊界的雙曲距離是無窮大**，因此邊界可以容納無限多個節點
- **角度在龐加萊圓盤中被保角保留**（conformal），但距離是被扭曲的

在這個模型中，**深度 d 的節點被放置在半徑 tanh(d × 0.6) 處**。深度 0（根）在圓心，深度 6 的葉節點半徑約 0.9985，幾乎緊貼邊界。

<figure>
  <img src="/images/hyperbolic/poincare-model.svg" alt="龐加萊圓盤模型" />
  <figcaption>龐加萊圓盤模型標準示意圖。圓盤內的曲線都是測地線（雙曲「直線」），靠近邊界的線段在視覺上看起來短，但在雙曲度量下長度相等。<br/>來源：Wikimedia Commons, CC BY-SA</figcaption>
</figure>

---

## 測地線與測地弧（Geodesic Arc）

在歐氏空間中，兩點之間的最短路徑是直線。在龐加萊圓盤中，「最短路徑」稱為**測地線（Geodesic）**，其形狀是：

- 若兩點與原點共線：是一段直徑
- 一般情況：是**與邊界圓正交的圓弧**

「與邊界圓正交」的意思是：這段圓弧與邊界圓交叉時，兩圓的切線互相垂直。

**幾何求解**：給定圓盤內兩點 p₁、p₂，測地弧的圓心 O 在 p₁p₂ 的垂直平分線上，且滿足正交條件：

> |O|² = R² + r²

其中 R 是圓盤半徑，r 是測地弧的半徑。這個條件保證測地弧確實正交於邊界圓。

<figure>
  <img src="/images/hyperbolic/poincare-geodesic.svg" alt="龐加萊圓盤中的測地線與平行線" />
  <figcaption>龐加萊圓盤中的測地線。通過圓盤中心的直線是直徑測地線，其餘都是正交於邊界圓的圓弧。注意：有無數條測地線可以通過一個點而不與給定測地線相交，這正是雙曲幾何「平行公理」失效的體現。<br/>來源：Wikimedia Commons, CC BY-SA</figcaption>
</figure>

---

## Möbius 加法（Möbius Addition）

龐加萊圓盤配備了一個**非交換的群運算**，稱為 Möbius 加法（⊕）。它描述的是「雙曲位移」：

> u ⊕ v = ((1 + 2⟨u,v⟩ + |v|²)u + (1 − |u|²)v) / (1 + 2⟨u,v⟩ + |u|²|v|²)

這個運算的重要性質：

- **u ⊕ 0 = u，0 ⊕ u = u**（0 是單位元）
- **一般情況 u ⊕ v ≠ v ⊕ u**（非交換）
- **(-u) ⊕ u = 0**（(-u) 是 u 的逆元）

Möbius 加法讓我們可以計算兩點之間的雙曲距離——把其中一點「平移」到原點，測量另一點到原點的距離即可。

<figure>
  <img src="/images/hyperbolic/mobius-transformation.svg" alt="Möbius 變換作用在保角格線上" />
  <figcaption>Möbius 變換（保角變換）作用在格線上的效果。格線在變換後彎曲，但任意兩條線的交角保持不變——這就是「保角」（conformal）的含義。龐加萊圓盤中的 Möbius 加法正是此類保角變換的特例。<br/>來源：Wikimedia Commons, CC BY-SA</figcaption>
</figure>

---

## WordNet 與上下位詞關係

WordNet 是由普林斯頓大學建立的大型英語詞彙資料庫，將詞語依語意關係組織成網路。其核心關係是：

| 關係 | 意義 | 範例 |
|------|------|------|
| **Hypernym（上位詞）** | 更廣泛的概念 | dog → mammal（狗是哺乳類） |
| **Hyponym（下位詞）** | 更具體的概念 | mammal → dog（哺乳類包含狗） |

本作品選取 33 個具代表性的 WordNet 節點，從抽象的「實體 entity」（深度 0）到具體的「貴賓犬 poodle」（深度 6），形成一棵六層深度的語意樹，展示雙曲嵌入如何自然表達這種層次。

<figure>
  <img src="/images/hyperbolic/wordnet-hierarchy.png" alt="WordNet 詞彙層次網路" />
  <figcaption>WordNet 詞彙網路實際截圖，顯示 "dog" 在 WordNet 中的上下位詞關係。每個節點為一個 synset（同義詞集），連線表示上下位詞關係，向上為更抽象的概念。<br/>來源：Wikimedia Commons, CC BY-SA 2.5</figcaption>
</figure>

---

## LCA（最近公共祖先）

LCA（Lowest Common Ancestor，最近公共祖先）是給定兩個節點 u、v，在它們的共同祖先中，**深度最大（離根最遠）** 的那一個。

**演算法**（本實作）：

1. 從 u 往上走到根，把所有祖先（含 u 本身）加入集合 S
2. 從 v 往上走，找到第一個在 S 中的節點，即為 LCA

**直觀意義**：LCA 是兩個概念「分叉」的地方。

- dog ↔ poodle 的 LCA 是 dog（深度 3）
- dog ↔ cat 的 LCA 是 mammal（深度 2）
- dog ↔ word 的 LCA 是 entity（深度 0）

LCA 的深度反映了兩個概念的共同性：LCA 越深，說明兩者越接近，共同點越具體。

<figure style="max-width: 260px; margin-left: auto; margin-right: auto;">
  <img src="/images/hyperbolic/lca.svg" alt="最近公共祖先示意圖" style="max-width: 100%; max-height: 360px;" />
  <figcaption style="max-width: 100%;">LCA 示意圖：節點 1 與節點 6 的最近公共祖先是節點 2，而非根節點 0，因為節點 2 是深度最大的共同祖先。<br/>來源：Wikimedia Commons, CC BY-SA 4.0</figcaption>
</figure>

---

## 路徑距離（Tree Path Distance）

路徑距離是兩個節點在樹中需要走的**最少邊數**（hops）。公式：

> **path(u, v) = depth(u) + depth(v) − 2 × depth(LCA)**

直觀理解：先從 u 走到 LCA 需要 depth(u) − depth(LCA) 步，再從 LCA 走到 v 需要 depth(v) − depth(LCA) 步，兩段加起來即得。

| 節點對 | LCA | 路徑距離 |
|--------|-----|---------|
| dog ↔ poodle | dog | 1 hop |
| dog ↔ cat | mammal | 2 hops |
| dog ↔ bird | vertebrate | 4 hops |
| dog ↔ word | entity | 9 hops |

路徑距離是**真正的語意距離**——它直接來自 WordNet 的語意結構，不受任何幾何嵌入的影響。

---

## Wu-Palmer 相似度（Wu-Palmer Similarity）

Wu-Palmer 相似度由 Zhibiao Wu 與 Martha Palmer 於 1994 年提出，是 NLP 中廣泛使用的 WordNet 語意相似度指標。

**公式**：

> **sim_WP(u, v) = 2 × depth(LCA) / (depth(u) + depth(v))**

**性質**：

| 特性 | 說明 |
|------|------|
| 範圍 | [0, 1]，越接近 1 越相似 |
| sim(u, u) | 永遠 = 1（同節點） |
| 分子越大 | LCA 越深 → 共同點越具體 → 越相似 |
| 分母越大 | 兩節點越深 → 若 LCA 不夠深則越不相似 |

**數值範例**：

| 節點對 | depth(LCA) | depth(u) + depth(v) | Wu-Palmer |
|--------|------------|----------------------|-----------|
| dog ↔ poodle | 3 | 3 + 4 = 7 | **0.857** |
| dog ↔ cat | 2 | 3 + 3 = 6 | **0.667** |
| dog ↔ bird | 1 | 3 + 3 = 6 | **0.333** |
| dog ↔ word | 0 | 3 + 0 = 3 | **0.000** |

**與路徑距離的比較**：路徑距離是整數（越小越相似），Wu-Palmer 是 0–1 的歸一化相似度（越大越相似），且對深度有正規化效果——兩個都在很深層級的節點，即使路徑距離相同，Wu-Palmer 也可能比淺層節點對更高。
