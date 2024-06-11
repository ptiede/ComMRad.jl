import{d as c,o as t,c as s,j as e,k as h,g as u,t as g,_ as m,F as _,E as p,b as f,M as b,I as r,a as i}from"./chunks/framework.D9ypSEX3.js";const v={class:"img-box"},I=["href"],y=["src"],k={class:"transparent-box1"},x={class:"caption"},T={class:"transparent-box2"},M={class:"subcaption"},w={class:"opacity-low"},B=c({__name:"GalleryImage",props:{href:{},src:{},caption:{},desc:{}},setup(d){return(a,o)=>(t(),s("div",v,[e("a",{href:a.href},[e("img",{src:h(u)(a.src),height:"150px",alt:""},null,8,y),e("div",k,[e("div",x,[e("h2",null,g(a.caption),1)])]),e("div",T,[e("div",M,[e("p",w,g(a.desc),1)])])],8,I)]))}}),P=m(B,[["__scopeId","data-v-fccfcd4e"]]),$={class:"gallery-image"},G=c({__name:"Gallery",props:{images:{}},setup(d){return(a,o)=>(t(),s("div",$,[(t(!0),s(_,null,p(a.images,n=>(t(),f(P,b({ref_for:!0},n),null,16))),256))]))}}),l=m(G,[["__scopeId","data-v-a34ec853"]]),S=e("h1",{id:"tutorials",tabindex:"-1"},[i("Tutorials "),e("a",{class:"header-anchor",href:"#tutorials","aria-label":'Permalink to "Tutorials"'},"​")],-1),C=e("p",null,"This page contains a collection of tutorials that cover a range of topics from beginner to advanced. These demonstrate how to use Comrade in a variety of scenarios. While most of them consider the EHT, they should work more generally for any VLBI arrays.",-1),H=e("h2",{id:"beginner-tutorials",tabindex:"-1"},[i("Beginner Tutorials "),e("a",{class:"header-anchor",href:"#beginner-tutorials","aria-label":'Permalink to "Beginner Tutorials"'},"​")],-1),L=e("h2",{id:"intermediate-tutorials",tabindex:"-1"},[i("Intermediate Tutorials "),e("a",{class:"header-anchor",href:"#intermediate-tutorials","aria-label":'Permalink to "Intermediate Tutorials"'},"​")],-1),V=e("h2",{id:"advanced-tutorials",tabindex:"-1"},[i("Advanced Tutorials "),e("a",{class:"header-anchor",href:"#advanced-tutorials","aria-label":'Permalink to "Advanced Tutorials"'},"​")],-1),z=JSON.parse('{"title":"Tutorials","description":"","frontmatter":{},"headers":[],"relativePath":"tutorials/index.md","filePath":"tutorials/index.md","lastUpdated":null}'),D={name:"tutorials/index.md"},A=c({...D,setup(d){const a=[{href:"beginner/LoadingData",src:"../assets/vis.png",caption:"Loading Data with Pyehtim",desc:"How to load data using standard eht-imaging in Julia."},{href:"beginner/GeometricModeling",src:"../assets/geom_model.png",caption:"Geometric Modeling of M87*",desc:"Modeling a black hole with simple geometric models"}],o=[{href:"intermediate/ClosureImaging",src:"../assets/closure.png",caption:"Closure Imaging of M87*",desc:"Creating an image of a black hole using only closure information"},{href:"intermediate/StokesIImaging",src:"../assets/stokesI.png",caption:"Simultaneous Imaging and Gain Modeling of M87*",desc:"Imaging a black hole with simultaneous gain modeling (selfcal) using complex visibilities"},{href:"intermediate/PolarizedImaging",src:"../assets/telescopes.png",caption:"Full Stokes Imaging using RIME",desc:"Simultaneous instrument and polarized imaging of VLBI data."}],n=[{href:"advanced/HybridImaging",src:"../assets/hybrid.png",caption:"Hybrid ring modeling and residual imaging of M87*",desc:"How to combine everything to model the ring and create a residual image of M87*."}];return(E,N)=>(t(),s("div",null,[S,C,H,r(l,{images:a}),L,r(l,{images:o}),V,r(l,{images:n})]))}});export{z as __pageData,A as default};
