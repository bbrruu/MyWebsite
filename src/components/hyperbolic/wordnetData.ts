import type { WordNode } from './types';

export const wordNodes: WordNode[] = [
  // depth 0
  {
    id: 'entity',
    label: '實體 entity',
    parentId: null,
    depth: 0,
    children: ['physical-object', 'abstraction'],
  },

  // depth 1
  {
    id: 'physical-object',
    label: '物體 physical object',
    parentId: 'entity',
    depth: 1,
    children: ['living-thing', 'artifact'],
  },
  {
    id: 'abstraction',
    label: '抽象 abstraction',
    parentId: 'entity',
    depth: 1,
    children: ['relation'],
  },

  // depth 2
  {
    id: 'living-thing',
    label: '生物 living thing',
    parentId: 'physical-object',
    depth: 2,
    children: ['animal', 'plant'],
  },
  {
    id: 'artifact',
    label: '人造物 artifact',
    parentId: 'physical-object',
    depth: 2,
    children: ['vehicle', 'tool'],
  },
  {
    id: 'relation',
    label: '關係 relation',
    parentId: 'abstraction',
    depth: 2,
    children: ['language'],
  },

  // depth 3
  {
    id: 'animal',
    label: '動物 animal',
    parentId: 'living-thing',
    depth: 3,
    children: ['mammal', 'bird', 'reptile'],
  },
  {
    id: 'plant',
    label: '植物 plant',
    parentId: 'living-thing',
    depth: 3,
    children: ['tree', 'flower'],
  },
  {
    id: 'vehicle',
    label: '交通工具 vehicle',
    parentId: 'artifact',
    depth: 3,
    children: ['car', 'bicycle'],
  },
  {
    id: 'tool',
    label: '工具 tool',
    parentId: 'artifact',
    depth: 3,
    children: ['hammer'],
  },
  {
    id: 'language',
    label: '語言 language',
    parentId: 'relation',
    depth: 3,
    children: ['word', 'sentence'],
  },

  // depth 4
  {
    id: 'mammal',
    label: '哺乳類 mammal',
    parentId: 'animal',
    depth: 4,
    children: ['dog', 'cat', 'whale'],
  },
  {
    id: 'bird',
    label: '鳥類 bird',
    parentId: 'animal',
    depth: 4,
    children: ['sparrow', 'eagle'],
  },
  {
    id: 'reptile',
    label: '爬蟲類 reptile',
    parentId: 'animal',
    depth: 4,
    children: ['lizard', 'snake'],
  },
  {
    id: 'tree',
    label: '樹木 tree',
    parentId: 'plant',
    depth: 4,
    children: [],
  },
  {
    id: 'flower',
    label: '花卉 flower',
    parentId: 'plant',
    depth: 4,
    children: [],
  },
  {
    id: 'car',
    label: '汽車 car',
    parentId: 'vehicle',
    depth: 4,
    children: [],
  },
  {
    id: 'bicycle',
    label: '自行車 bicycle',
    parentId: 'vehicle',
    depth: 4,
    children: [],
  },
  {
    id: 'hammer',
    label: '鎚子 hammer',
    parentId: 'tool',
    depth: 4,
    children: [],
  },
  {
    id: 'word',
    label: '詞語 word',
    parentId: 'language',
    depth: 4,
    children: [],
  },
  {
    id: 'sentence',
    label: '句子 sentence',
    parentId: 'language',
    depth: 4,
    children: [],
  },

  // depth 5
  {
    id: 'dog',
    label: '狗 dog',
    parentId: 'mammal',
    depth: 5,
    children: ['poodle', 'retriever', 'husky'],
  },
  {
    id: 'cat',
    label: '貓 cat',
    parentId: 'mammal',
    depth: 5,
    children: ['persian', 'siamese'],
  },
  {
    id: 'whale',
    label: '鯨魚 whale',
    parentId: 'mammal',
    depth: 5,
    children: [],
  },
  {
    id: 'sparrow',
    label: '麻雀 sparrow',
    parentId: 'bird',
    depth: 5,
    children: [],
  },
  {
    id: 'eagle',
    label: '老鷹 eagle',
    parentId: 'bird',
    depth: 5,
    children: [],
  },
  {
    id: 'lizard',
    label: '蜥蜴 lizard',
    parentId: 'reptile',
    depth: 5,
    children: [],
  },
  {
    id: 'snake',
    label: '蛇 snake',
    parentId: 'reptile',
    depth: 5,
    children: [],
  },

  // depth 6
  {
    id: 'poodle',
    label: '貴賓犬 poodle',
    parentId: 'dog',
    depth: 6,
    children: [],
  },
  {
    id: 'retriever',
    label: '拉不拉多 retriever',
    parentId: 'dog',
    depth: 6,
    children: [],
  },
  {
    id: 'husky',
    label: '哈士奇 husky',
    parentId: 'dog',
    depth: 6,
    children: [],
  },
  {
    id: 'persian',
    label: '波斯貓 persian',
    parentId: 'cat',
    depth: 6,
    children: [],
  },
  {
    id: 'siamese',
    label: '暹羅貓 siamese',
    parentId: 'cat',
    depth: 6,
    children: [],
  },
];
