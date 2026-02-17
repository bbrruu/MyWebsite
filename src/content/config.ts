import { defineCollection, z } from 'astro:content';


const blogCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    pubDate: z.date(),
    // 增加以下炫砲欄位
    mood: z.string().default('還行'), // 心情指標
    techStack: z.array(z.string()).default([]), // 當天研究的技術
    status: z.enum(['Stable', 'Deploying', 'Debugging']).default('Stable'), // 系統狀態感
    location: z.string().default('Taipei, Taiwan'),
    category: z.enum(['EVERYDAY-LIFE', 'GAME', 'REFLECTION', 'LEARNING']).default('EVERYDAY-LIFE'),
  }),
});

const researchCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    status: z.enum(['Published', 'In Progress', 'Term Paper']).default('In Progress'), 
    field: z.string().optional(), // 研究領域改為選填
    abstract: z.string().optional(), // 摘要改為選填
    pdfUrl: z.string().url().optional(),
    pubDate: z.date(),
    category: z.string().default('General Research'), // 預設研究類別
    author: z.string().default('TBC'), // 預設作者名稱
  }),
});

const readingCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(), // 心得標題
    bookTitle: z.string(), // 書名
    author: z.string(), // 作者
    pubDate: z.date(),
    rating: z.number().min(1).max(5).default(5), // 評分
  }),
});

const musicCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(), // 分享標題
    songName: z.string(), // 歌名
    artist: z.string(), // 歌手/樂團
    album: z.string().optional(),
    pubDate: z.date(),
    link: z.string().url().optional(), // 音樂連結
    youtubeId: z.string().optional(), // 例如: 'dQw4w9WgXcQ'
    lyrics: z.string().default(''),   // 存放歌詞文字
  }),
});

export const collections = {
  'blog': blogCollection,
  'research': researchCollection,
  'reading': readingCollection,
  'music': musicCollection,
};