import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
mkdirSync('build/qa',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--mute-audio','--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
const context=await browser.newContext({viewport:{width:1280,height:720}});
await context.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('QA prohibits pointer capture');};});
const page=await context.newPage(),errors=[],requests=[];let ready=false;
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());if(m.text().includes('BULONG_READY'))ready=true;});
page.on('request',r=>requests.push(r.url()));
try{
  await page.goto((process.env.GAME_URL||'http://127.0.0.1:8062')+'/?qa=1');
  for(let i=0;i<240&&!ready;i++)await page.waitForTimeout(250);
  assert.ok(ready);await page.waitForTimeout(500);
  assert.equal(await page.evaluate(()=>typeof window.bulongCommand),'undefined');assert.equal(await page.evaluate(()=>typeof window.bulongTest),'undefined');
  await page.mouse.click(215,382);await page.waitForTimeout(400);
  await page.mouse.move(920,575);await page.mouse.wheel(0,600);await page.waitForTimeout(250);
  await page.mouse.click(480,575);await page.waitForTimeout(500);await page.screenshot({path:'build/qa/v02-release-arrival.png'});
  assert.equal(await page.evaluate(()=>document.pointerLockElement),null);
  await page.locator('#fullscreen').click();await page.waitForTimeout(400);assert.ok(await page.evaluate(()=>!!document.fullscreenElement));
  await page.evaluate(()=>document.exitFullscreen());assert.equal(await page.evaluate(()=>document.pointerLockElement),null);
  assert.ok(requests.every(u=>new URL(u).hostname==='127.0.0.1'));assert.deepEqual(errors,[]);
  writeFileSync('build/qa/v02-release-report.json',JSON.stringify({status:'passed',debugBridge:false,noCursorCapture:true,errors,requests},null,2));
  console.log('PASS silent release boot, onboarding, fullscreen menus, no debug bridge and no external requests');
}catch(e){console.error(e);process.exitCode=1;}
finally{await browser.close();}
