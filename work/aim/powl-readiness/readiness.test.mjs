// Run: node --test work/aim/powl-readiness/readiness.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
const path = new URL("./index.ts", import.meta.url);
const source = readFileSync(path, "utf8")
  .replace(/^import .*;\s*$/gm, "")
  .replace("value: unknown, status = 200", "value, status = 200")
  .replace("token: string", "token")
  .replace(": Record<string, unknown> | null", "")
  .replace("let payload: unknown;", "let payload;")
  .replace(" as Record<string, unknown>", "")
  .replace("view: string, columns: string", "view, columns");
function harness({ claims = { role: "service_role" }, action = "readiness", fail = false, missing = false } = {}) {
 let handler; const calls = [];
 const token = "x." + Buffer.from(JSON.stringify(claims)).toString("base64url") + ".x";
 const fakeFetch = async (url, options) => {
   calls.push({url,options});
   if (fail) return {ok:false};
   const data = missing ? [] : url.includes("v_mission_readiness")
     ? [{readiness:"DELIVERED_NOT_ACKNOWLEDGED",verified_evidence_count:1,open_risks:1,sent_receipts:1,acknowledged_receipts:0}]
     : [{governance_readiness:"NOT_READY",passed_gates:0}];
   return {ok:true,json:async()=>data};
 };
 const Deno = {serve:fn=>handler=fn,env:{get:k=>k==="SUPABASE_URL"?"https://sandbox.example":k==="SUPABASE_SERVICE_ROLE_KEY"?"test-service-key":null}};
 runInNewContext(source,{Deno,Response,fetch:fakeFetch,atob,AbortSignal,JSON});
 const request = (opts={}) => handler(new Request("https://example.test",{method:opts.method??"POST",headers:opts.auth===false?{}:{authorization:"Bearer "+token},body:opts.method==="GET"?undefined:opts.invalidJson?"{":JSON.stringify({action:opts.action??action})}));
 return {request,calls};
}
test("rejects wrong method",async()=>assert.equal((await harness().request({method:"GET"})).status,405));
test("rejects missing bearer token",async()=>assert.equal((await harness().request({auth:false})).status,401));
test("rejects non-service role",async()=>assert.equal((await harness({claims:{role:"anon"}}).request()).status,403));
test("rejects malformed JSON",async()=>assert.equal((await harness().request({invalidJson:true})).status,400));
test("rejects unsupported action",async()=>assert.equal((await harness({action:"trade"}).request()).status,400));
test("fails closed when upstream read fails",async()=>assert.equal((await harness({fail:true}).request()).status,503));
test("fails closed when mission missing",async()=>assert.equal((await harness({missing:true}).request()).status,503));
test("returns actual sandbox readiness and no autonomy claim",async()=>{
 const h=harness();const response=await h.request();const body=await response.json();
 assert.equal(response.status,200);assert.equal(body.readiness,"DELIVERED_NOT_ACKNOWLEDGED");
 assert.equal(body.unattended_execution_verified,false);
 assert.equal(h.calls.length,2);
 assert.ok(h.calls.every(x=>x.options.headers["Accept-Profile"]==="aim"));
 assert.ok(h.calls.every(x=>x.options.method===undefined));
});
