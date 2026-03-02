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
    category: z.enum(['旅行', '日常', '省思']).default('日常'),
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
    coverImage: z.string().optional(), // 書封圖片路徑（選填）
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

const projectsCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.date(),
    status: z.enum(['Active', 'WIP', 'Archived']).default('Active'),
    techStack: z.array(z.string()).default([]),
    demoUrl: z.string().optional(),
    githubUrl: z.string().optional(),
    coverImage: z.string().optional(),
    featured: z.boolean().default(false),
    category: z.enum(['App', 'Tool', 'Experiment', 'Other']).default('App'),
  }),
});

const notesCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    pubDate: z.date(),
    tags: z.array(z.string()).default([]),
    category: z.enum(['語言', '歷史文化', 'NLP', '天文']).default('語言'),
    demoUrl: z.string().optional(),
  }),
});

export const collections = {
  'blog': blogCollection,
  'research': researchCollection,
  'reading': readingCollection,
  'music': musicCollection,
  'projects': projectsCollection,
  'notes': notesCollection,
};