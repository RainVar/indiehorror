import {chromium} from 'playwright';
const browser=await chromium.launch({headless:true,args:['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1280,height:720}});
await page.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('Pointer capture forbidden');};});
try{
 await page.goto('http://127.0.0.1:8061/?qa=1');
 await page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:60000});
 const cmd=async d=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),d);await page.waitForTimeout(450);};
 await cmd({action:'touch',value:true});await cmd({action:'start'});await cmd({action:'close_note'});
 await cmd({action:'quality',value:'high'});await cmd({action:'interact',id:'fuse'});
 for(const bias of [0.1,0.5,1,2]){
   await cmd({action:'shadow_probe',bias,normal:2});
   await cmd({action:'teleport',x:0,z:15.2,yaw:0,pitch:10});await page.waitForTimeout(1000);
   await page.screenshot({path:`build/qa/surfaces/shadow-bias-${bias}.png`});
 }
 console.log('Shadow comparison captured without pointer lock');
}finally{await browser.close();}
