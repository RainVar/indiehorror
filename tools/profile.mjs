import {chromium} from 'playwright';
import {writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true,args:['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1280,height:720}});
await page.goto('http://127.0.0.1:8061/?qa=1');
await page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:45000});
const cmd=async d=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),d);await page.waitForTimeout(100);};
await cmd({action:'touch',value:true});await cmd({action:'start'});await cmd({action:'close_note'});await cmd({action:'interact',id:'fuse'});
const results=[];
for(const quality of ['low','medium','high']){
  await cmd({action:'quality',value:quality});
  for(const [name,x,z,yaw] of [['sala',0,6.7,0],['kitchen',-4.4,6.7,0.5],['altar',5.0,-5.0,-0.25],['exterior',0,15.2,0]]){
    await cmd({action:'teleport',x,z,yaw,pitch:-5});await page.waitForTimeout(1800);
    const s=await page.evaluate(()=>window.bulongTest.state);
    results.push({quality,scene:name,fps:s.fps,draws:s.draws,triangles:s.triangles,vram_mb:Math.round(s.vram/1048576*10)/10});
    if(quality==='medium')await page.screenshot({path:`build/qa/scene-${name}.png`});
  }
}
writeFileSync('build/qa/performance.json',JSON.stringify({viewport:[1280,720],type:'Desktop Chromium, not a mobile hardware benchmark',samples:results},null,2));
console.log(JSON.stringify(results));await browser.close();
