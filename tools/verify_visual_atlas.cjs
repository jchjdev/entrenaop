// Verifica comportamiento del atlas y tamaño en el navegador, sin API externa.
const {chromium} = require('C:/Users/JVR/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch({headless: true, channel:'msedge'});
  const errors = [];
  const manifest = JSON.parse(fs.readFileSync('docs/visual-audit/2026-10-07/manifest.json','utf8'));
  const page = await browser.newPage();
  page.on('pageerror', error => errors.push(error.message));
  for(const mode of ['app', 'admin']) {
    await page.goto('file:///' + path.resolve('build/visual-atlas-20261007/' + mode + '-preview.html').replaceAll('\\','/'));
    const frame = page.frameLocator('iframe');
    await frame.locator('[data-image]').waitFor();
    const count = await frame.locator('[data-screen] option').count();
    if(count !== manifest.screens.filter(s=>s.mode===mode).length) throw Error('Vista previa desactualizada: '+mode);
    for(let i=0;i<count;i++) {
      await frame.locator('[data-screen]').selectOption(String(i));
      const result = await frame.locator('[data-image]').evaluate(async img => {
        await img.decode(); return {width:img.naturalWidth,alt:img.alt};
      });
      if(!result.width || !result.alt) throw Error('Imagen/etiqueta ausente: '+mode+'/'+i);
      const states = await frame.locator('[data-state] option').count();
      for(let state=1;state<states;state++) {
        await frame.locator('[data-state]').selectOption(String(state));
        await frame.locator('[data-image]').evaluate(img => img.decode());
      }
    }
    const flowCount = await frame.locator('[data-flow] option').count();
    for(let i=0;i<flowCount;i++) {
      await frame.locator('[data-flow]').selectOption(String(i));
      await frame.locator('[data-steps] button').first().click();
    }
    for(const width of [320,736,1024]) {
      await page.setViewportSize({width,height:1100});
      await page.waitForTimeout(100);
      const clipping = await frame.locator('#atlas-'+mode).evaluate(root => ({scroll:root.scrollWidth,width:root.clientWidth}));
      if(clipping.scroll > clipping.width+1) throw Error('Desbordamiento '+mode+' '+width+' '+JSON.stringify(clipping));
    }
    await page.setViewportSize({width:736,height:1100});
    await frame.locator('[data-screen]').selectOption(mode==='app'?'2':'1');
    await frame.locator('[data-image]').evaluate(img=>img.decode());
    await page.waitForTimeout(300);
    await page.screenshot({path:'build/visual-atlas-20261007/'+mode+'-atlas-preview.png',fullPage:true});
    console.log(mode+': '+count+' vistas, '+flowCount+' recorridos, imágenes/estados y anchuras correctos');
  }
  await browser.close();
  if(errors.length) throw Error(errors.join('\n'));
  let images = 0;
  for(const screen of manifest.screens) {
    if(!screen.source || !fs.existsSync(screen.source)) throw Error('Fuente ausente '+screen.class);
    for(const image of screen.captures) {
      if(image.commit !== manifest.sourceCommit) throw Error('Commit de evidencia incorrecto');
      if(!fs.existsSync('docs/visual-audit/2026-10-07/'+image.file)) throw Error('Evidencia ausente');
      images++;
    }
  }
  console.log('Manifiesto: '+manifest.screens.length+' vistas y '+images+' imágenes con fuente/commit contrastados.');
})().catch(error => {console.error(error);process.exitCode=1;});
