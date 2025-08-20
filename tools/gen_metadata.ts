#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.log('Usage: node gen_metadata.ts <config.yaml> <metadata_dir>');
    process.exit(1);
  }

  const configPath = args[0];
  const metadataDir = args[1];

  // Read configuration
  if (!fs.existsSync(configPath)) {
    console.log(`Config file not found: ${configPath}`);
    process.exit(1);
  }

  const configContent = fs.readFileSync(configPath, 'utf8');
  const config = yaml.load(configContent);

  if (!config.store) {
    console.log('No store configuration found in config file');
    process.exit(1);
  }

  console.log(`Generating metadata for ${config.app_name}`);

  // Create metadata directories
  const languages = ['ja-JP', 'en-US'];
  
  for (const lang of languages) {
    const langDir = path.join(metadataDir, lang);
    fs.mkdirSync(langDir, { recursive: true });

    // Generate metadata files
    const langSuffix = lang === 'ja-JP' ? '_ja' : '_en';
    
    // App name
    const nameFile = path.join(langDir, 'name.txt');
    fs.writeFileSync(nameFile, config.app_name || '');

    // Subtitle
    const subtitleFile = path.join(langDir, 'subtitle.txt');
    const subtitle = config.store[`subtitle${langSuffix}`] || '';
    fs.writeFileSync(subtitleFile, subtitle);

    // Keywords
    const keywordsFile = path.join(langDir, 'keywords.txt');
    const keywords = config.store[`keywords${langSuffix}`] || [];
    fs.writeFileSync(keywordsFile, Array.isArray(keywords) ? keywords.join(', ') : keywords);

    // Promotional text
    const promoFile = path.join(langDir, 'promotional_text.txt');
    const promo = config.store[`promo${langSuffix}`] || '';
    fs.writeFileSync(promoFile, promo);

    // Description (if available)
    const descFile = path.join(langDir, 'description.txt');
    const description = config.store[`description${langSuffix}`] || config.store[`promo${langSuffix}`] || '';
    fs.writeFileSync(descFile, description);

    console.log(`✅ Generated metadata for ${lang}`);
  }

  // Generate copyright file
  const copyrightFile = path.join(metadataDir, 'copyright.txt');
  const currentYear = new Date().getFullYear();
  fs.writeFileSync(copyrightFile, `© ${currentYear} ${config.app_name || 'App'}. All rights reserved.`);

  // Generate primary category file  
  const categoryFile = path.join(metadataDir, 'primary_category.txt');
  fs.writeFileSync(categoryFile, 'GAMES');

  // Generate secondary category file
  const secondaryCategoryFile = path.join(metadataDir, 'secondary_category.txt');
  fs.writeFileSync(secondaryCategoryFile, 'ARCADE');

  console.log('✅ Generated all metadata files');
}

main();