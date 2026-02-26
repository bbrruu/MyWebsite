import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

export const GET: APIRoute = async () => {
  const [blogs, research, reading, music, projects] = await Promise.all([
    getCollection('blog'),
    getCollection('research'),
    getCollection('reading'),
    getCollection('music'),
    getCollection('projects'),
  ]);

  const results = [
    ...blogs.map(e => ({ type: 'BLOG', title: e.data.title, url: `/blog/${e.id}`, subtitle: e.data.category })),
    ...research.map(e => ({ type: 'RESEARCH', title: e.data.title, url: `/research/${e.id}`, subtitle: e.data.field || '' })),
    ...reading.map(e => ({ type: 'READING', title: e.data.title, url: `/reading/${e.id}`, subtitle: e.data.bookTitle })),
    ...music.map(e => ({ type: 'MUSIC', title: e.data.title, url: `/music/${e.id}`, subtitle: `${e.data.artist} — ${e.data.songName}` })),
    ...projects.map(e => ({ type: 'PROJECT', title: e.data.title, url: `/projects/${e.id}`, subtitle: e.data.description })),
  ];

  return new Response(JSON.stringify(results), {
    headers: { 'Content-Type': 'application/json' },
  });
};
