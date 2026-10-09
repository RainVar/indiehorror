import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true,args:['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1280,height:720}});
await page.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('Pointer capture forbidden during release boot check');};});
let ready=false;const errors=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());if(m.text().includes('BULONG_READY'))ready=true;});
try{
 await page.goto('http://127.0.0.1:8060/?qa=1');
 const start=Date.now();while(!ready&&Date.now()-start<60000)await page.waitForTimeout(250);
 assert.ok(ready);await page.waitForTimeout(1500);
 assert.equal(await page.evaluate(()=>typeof window.bulongCommand),'undefined');
 await page.screenshot({path:'build/qa/surfaces/release-title.png'});
 assert.deepEqual(errors,[]);assert.equal(await page.evaluate(()=>!!document.pointerLockElement),false);
 writeFileSync('build/qa/surfaces/release-render.json',JSON.stringify({status:'passed',debugBridge:false,pointerCapture:false,errors},null,2));
 console.log('PASS release render, no errors, no debug bridge, no mouse capture');
}catch(e){console.error(e);process.exitCode=1;}
finally{await browser.close();}
