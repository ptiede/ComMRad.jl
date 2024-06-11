import{_ as i,c as a,o as s,a6 as t}from"./chunks/framework.DeCGYPSK.js";const E=JSON.parse('{"title":"Optimization Extension","description":"","frontmatter":{},"headers":[],"relativePath":"ext/optimization.md","filePath":"ext/optimization.md","lastUpdated":null}'),e={name:"ext/optimization.md"},n=t(`<h1 id="Optimization-Extension" tabindex="-1">Optimization Extension <a class="header-anchor" href="#Optimization-Extension" aria-label="Permalink to &quot;Optimization Extension {#Optimization-Extension}&quot;">​</a></h1><p>To optimize our posterior, we use the <a href="https://github.com/SciML/Optimization.jl" target="_blank" rel="noreferrer"><code>Optimization.jl</code></a> package. Optimization provides a global interface to several Julia optimizers. The base call most people should look at is <a href="/Comrade.jl/previews/PR357/api#Comrade.comrade_opt"><code>comrade_opt</code></a> which serves as the general purpose optimization algorithm.</p><p>To see what optimizers are available and what options are available, please see the <code>Optimizations.jl</code> <a href="http://optimization.sciml.ai/dev/" target="_blank" rel="noreferrer">docs</a>.</p><h2 id="Example" tabindex="-1">Example <a class="header-anchor" href="#Example" aria-label="Permalink to &quot;Example {#Example}&quot;">​</a></h2><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Comrade</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Optimization</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> OptimizationOptimJL</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># Some stuff to create a posterior object</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">post </span><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># of type Comrade.Posterior</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">xopt, sol </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> comrade_opt</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(post, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">LBFGS</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(); adtype</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Val</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:Zygote</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span></code></pre></div>`,5),p=[n];function o(l,h,r,k,d,c){return s(),a("div",null,p)}const g=i(e,[["render",o]]);export{E as __pageData,g as default};
