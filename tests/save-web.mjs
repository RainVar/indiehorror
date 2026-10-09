import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true,args:['--mute-audio','--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
try{
 const page=await browser.newPage();await page.goto('http://127.0.0.1:8061/?qa=1');await page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:60000});
 const cmd=async d=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),d);await page.waitForTimeout(300);};
 for(const d of [{action:'start'},{action:'close_note'},{action:'interact',id:'fuse'},{action:'interact',id:'rules'},{action:'close_note'},{action:'save_probe'}])await cmd(d);
 const before=await page.evaluate(()=>window.bulongStorage);assert.ok(before.valid);assert.ok(before.persistent);
 await page.waitForTimeout(2200);await page.reload();await page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:60000});await cmd({action:'save_probe'});
 const after=await page.evaluate(()=>window.bulongStorage);assert.ok(after.valid);assert.deepEqual(after.data.checkpoint,before.data.checkpoint);
 writeFileSync('build/qa/v02-save-report.json',JSON.stringify({status:'passed',before,after},null,2));console.log('PASS real browser save persists through reload and validates');
}finally{await browser.close();}
