import { chromium, firefox } from 'playwright';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';

const name = process.env.BROWSER || 'chromium';
const browser = await (name === 'firefox' ? firefox : chromium).launch({headless:true,
  args:name === 'chromium' ? ['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist'] : [],
  firefoxUserPrefs:name === 'firefox' ? {'webgl.force-enabled':true} : undefined});
const context = await browser.newContext({viewport:{width:1280,height:720},screen:{width:1280,height:720}});
const page = await context.newPage();
const errors = [], results = [];
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => { if(m.type() === 'error') errors.push(m.text()); });
const wait = async (fn, message, timeout=60000) => {
  const start=Date.now();
  while(Date.now()-start<timeout){if(await page.evaluate(fn))return;await page.waitForTimeout(150);}
  throw new Error(message);
};
const state = () => page.evaluate(() => window.bulongTest.state);
const move = async (key, ms) => {await page.keyboard.down(key);await page.waitForTimeout(ms);await page.keyboard.up(key);await page.waitForTimeout(400);};
const check = async (name, fn) => {await fn();results.push({name,status:'passed'});console.log('PASS',name);};
mkdirSync('build/qa',{recursive:true});
try {
  await page.goto((process.env.GAME_URL || 'http://127.0.0.1:8061')+'/?qa=1');
  await wait(() => window.bulongTest?.state?.ready,'Game readiness');
  await page.waitForTimeout(900);
  await page.mouse.click(215,382);await page.waitForTimeout(400);
  await page.mouse.click(480,575);await page.waitForTimeout(500);
  await page.mouse.click(480,361);await page.waitForTimeout(500);
  await check('walk from actual spawn across patio and through front door', async () => {
    assert.ok((await state()).player[2]>14,'Starts outside, not teleported past the step');
    await move('w',1900);
    assert.ok((await state()).player[2]<11,`Patio blocks entry at z=${(await state()).player[2]}`);
    await move('w',500);
    assert.equal((await state()).target,'door_front');
    await page.keyboard.press('e');await page.waitForTimeout(450);
    await move('w',1300);
    assert.ok((await state()).player[2]<8,'Crosses the open front doorway');
    await move('s',3400);
    assert.ok((await state()).player[2]>13,'Can walk back off the patio');
  });
  if(process.env.ENTRY_ONLY!=='1'){
    await check('fullscreen transition releases mouse and resumes real movement/look',async()=>{
      // Browser API, not the game test bridge: emulate a host fullscreen shortcut.
      await page.evaluate(()=>document.addEventListener('keydown',e=>{
        if(e.code==='KeyG')document.documentElement.requestFullscreen();
      }));
      await page.keyboard.press('g');
      await wait(()=>!!document.fullscreenElement,'Fullscreen must actually engage',5000);
      await wait(()=>window.bulongTest.state.paused && !document.pointerLockElement,'Fullscreen must expose a usable pause menu',5000);
      await page.screenshot({path:`build/qa/${name}-fullscreen-paused.png`});
      await page.mouse.click(480,169);
      await wait(()=>!window.bulongTest.state.paused && !!document.pointerLockElement,'Resume must restore capture',5000);
      const before=await state();
      await page.mouse.move(660,360);await page.mouse.move(740,380);await page.waitForTimeout(500);
      assert.ok(Math.abs((await state()).yaw-before.yaw)>0.01,'Mouse changes view after fullscreen');
      const z=(await state()).player[2];await move('w',450);
      assert.ok(Math.abs((await state()).player[2]-z)>0.2,'Keyboard moves after fullscreen');
      await page.screenshot({path:`build/qa/${name}-fullscreen-playing.png`});
    });
    await check('pointer-lock loss pauses and resume recaptures',async()=>{
      await page.evaluate(()=>document.exitPointerLock());
      await wait(()=>window.bulongTest.state.paused && !document.pointerLockElement,'Unlock must pause',5000);
      await page.mouse.click(480,169);
      await wait(()=>!window.bulongTest.state.paused && !!document.pointerLockElement,'Unlock recovery',5000);
    });
    await check('fullscreen exit and shell button preserve usable controls',async()=>{
      await page.evaluate(()=>document.exitFullscreen());
      await wait(()=>!document.fullscreenElement && !document.pointerLockElement && window.bulongTest.state.paused,'Fullscreen exit must be safe',5000);
      await page.locator('#fullscreen').click();
      await wait(()=>!!document.fullscreenElement,'Shell fullscreen button works',5000);
      assert.equal(await page.evaluate(()=>document.pointerLockElement!==null),false);
      await page.mouse.click(480,169);
      await wait(()=>!window.bulongTest.state.paused && !!document.pointerLockElement,'Resume after shell button',5000);
    });
  }
  assert.deepEqual(errors,[]);
  writeFileSync(`build/qa/${name}-entry-fullscreen.json`,JSON.stringify({status:'passed',results,errors},null,2));
} catch(e) {
  await page.screenshot({path:`build/qa/${name}-entry-fullscreen-failure.png`});
  console.error(e);process.exitCode=1;
} finally {await browser.close();}
