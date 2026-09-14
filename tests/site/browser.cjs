'use strict';
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  fs.mkdirSync('site-results', {recursive:true});
  const browser=await chromium.launch({headless:true});
  const errors=[]; const results=[];
  const pages=['/','/privacy/','/terms/','/delete-account/','/contact/','/login-callback/','/404.html'];
  try {
    const context=await browser.newContext();
    const page=await context.newPage();
    page.on('pageerror',e=>errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`);});
    for (const width of [320,390,768,1440]) {
      await page.setViewportSize({width,height:1000});
      for (const path of pages) {
        await page.goto('http://127.0.0.1:8765'+path);
        await page.evaluate(()=>document.fonts.ready);
        const metrics=await page.evaluate(()=>({scroll:document.documentElement.scrollWidth,view:innerWidth,h1:document.querySelectorAll('h1').length}));
        assert(metrics.scroll<=metrics.view,`${width} ${path}: horizontal overflow ${metrics.scroll}`);
        assert.equal(metrics.h1,1);
        results.push({width,path,status:'PASS'});
      }
    }
    await page.setViewportSize({width:390,height:844});
    await page.goto('http://127.0.0.1:8765/');
    const menu=page.getByRole('button',{name:'القائمة'});
    await menu.click(); assert.equal(await menu.getAttribute('aria-expanded'),'true');
    await page.keyboard.press('Escape'); assert.equal(await menu.getAttribute('aria-expanded'),'false'); assert(await menu.evaluate(e=>e===document.activeElement));
    await menu.click(); await page.locator('#main-nav a[href="/#faq"]').click(); assert.equal(await menu.getAttribute('aria-expanded'),'false');
    await page.locator('summary').first().focus(); await page.keyboard.press('Enter'); assert(await page.locator('details').first().evaluate(e=>e.open));
    await page.locator('summary').first().press('Enter');
    await page.goto('http://127.0.0.1:8765/'); await page.evaluate(()=>document.fonts.ready);
    await page.screenshot({path:'site-results/mobile.png',fullPage:true});
    await page.setViewportSize({width:1440,height:1000}); await page.goto('http://127.0.0.1:8765/'); await page.evaluate(()=>document.fonts.ready);
    await page.screenshot({path:'site-results/desktop.png',fullPage:true});
    await page.screenshot({path:'site-results/desktop-first-screen.png'});
    await page.goto('http://127.0.0.1:8765/delete-account/'); await page.screenshot({path:'site-results/delete-account.png',fullPage:true});
    const nojs=await browser.newContext({javaScriptEnabled:false,viewport:{width:390,height:844}});
    const fallback=await nojs.newPage(); await fallback.goto('http://127.0.0.1:8765/'); assert(await fallback.locator('#main-nav').isVisible()); await fallback.locator('summary').first().click(); assert(await fallback.locator('details').first().evaluate(e=>e.open)); await nojs.close();
    assert.deepEqual(errors,[],'Browser/network/CSP errors');
    fs.writeFileSync('site-results/summary.json',JSON.stringify({pages:results,checks:['28 page/viewport combinations without horizontal overflow','Mobile navigation, Escape and focus return','Keyboard FAQ disclosure','No-JavaScript navigation and FAQ','No console, network or CSP errors'],errors},null,2));
    console.log('PASS: 28 page/viewport combinations and interaction checks.');
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
