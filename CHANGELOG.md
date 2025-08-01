# Changelog



<!-- "name: Unreleased" is a release tag -->

## [Unreleased](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/Unreleased) ()



### Documentation

 -  update changeme ([8f7cf1de331e8b0](https://github.com/bsorrentino/LangGraph-Swift/commit/8f7cf1de331e8b0faefad0d11552b952599a955c))









<!-- "name: v4.0.0-beta3" is a release tag -->

## [v4.0.0-beta3](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v4.0.0-beta3) (2025-08-01)


### Bug Fixes

 -  complex types casting of  state's attributes ([cb43df9c8cdeb45](https://github.com/bsorrentino/LangGraph-Swift/commit/cb43df9c8cdeb458676809db8d926e955dcf2867))
     > resolve #10


### Documentation

 -  update changeme ([c80ff06ef693e62](https://github.com/bsorrentino/LangGraph-Swift/commit/c80ff06ef693e624dc1fdb8025dfa8b77b3391c8))




### Test

 -  setup testing stuff ([31c819a6fe97196](https://github.com/bsorrentino/LangGraph-Swift/commit/31c819a6fe97196bd72c2b26dce627ad75393135))
    > work on #10






<!-- "name: v4.0.0-beta2" is a release tag -->

## [v4.0.0-beta2](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v4.0.0-beta2) (2025-07-22)



### Documentation

 -  update site documentation ([08cd96f96c4a1c6](https://github.com/bsorrentino/LangGraph-Swift/commit/08cd96f96c4a1c653a9a02eb93bcee03b1638e64))

 -  add comments ([ca8e95885ca3757](https://github.com/bsorrentino/LangGraph-Swift/commit/ca8e95885ca3757bc6487b7117a027a8a7ca65b5))

 -  update changeme ([a97b98b07310fe0](https://github.com/bsorrentino/LangGraph-Swift/commit/a97b98b07310fe0c87b4c988e91e623193bb4b2f))









<!-- "name: v4.0.0-beta1" is a release tag -->

## [v4.0.0-beta1](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v4.0.0-beta1) (2025-07-20)

### Features

 *  refine pause/resume process ([d13f67362f096a8](https://github.com/bsorrentino/LangGraph-Swift/commit/d13f67362f096a89022828935c899f36be0a5e79))
     > solve #5
   
 *  add support for interruptBefore configuration ([d5b0d8a2e81ede2](https://github.com/bsorrentino/LangGraph-Swift/commit/d5b0d8a2e81ede26e1b834db17e5aa5959968f77))
     > solve #5
   
 *  save checkpoints during workflow execution ([4b2e7a3c749ba27](https://github.com/bsorrentino/LangGraph-Swift/commit/4b2e7a3c749ba270ecc86e703738df7ba3d0cb06))
     > work on #5
   
 *  **Checkpoints.swift**  introduces Checkpoint and Tag structures along with a MemoryCheckpointSaver implementation ([fd676b90e65010c](https://github.com/bsorrentino/LangGraph-Swift/commit/fd676b90e65010cd15ee47ec876a8978855794a0))
   
 *  **LangGraph.swift**  introduce state update functionality ([af195a2534eb7a1](https://github.com/bsorrentino/LangGraph-Swift/commit/af195a2534eb7a14c5158785d28573fafeb27c2f))
   


### Documentation

 -  update readme ([919ad20d3a9ac49](https://github.com/bsorrentino/LangGraph-Swift/commit/919ad20d3a9ac49f3469ccf22cf36d49581dd3bc))

 -  update documentation ([bbc1cee1168f2a5](https://github.com/bsorrentino/LangGraph-Swift/commit/bbc1cee1168f2a5d737199207f8fac6585ac96f7))

 -  update documentation ([728bf21895437c1](https://github.com/bsorrentino/LangGraph-Swift/commit/728bf21895437c12c1d0d5431afc97b0ef4de33b))

 -  update changeme ([27bb1c001cb0b71](https://github.com/bsorrentino/LangGraph-Swift/commit/27bb1c001cb0b71c47d8edd817b3e42a630ffb32))


### Refactor

 -  remove deprecated finishPoint ([b59e14a5a96a530](https://github.com/bsorrentino/LangGraph-Swift/commit/b59e14a5a96a530d09a101a3f0aedebf2b025e9c))
   







<!-- "name: v3.2.0" is a release tag -->

## [v3.2.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v3.2.0) (2024-12-05)

### Features

 *  **LangGraph.swift**  add support for subgraphs and embedded streams ([18803f157c12e4c](https://github.com/bsorrentino/LangGraph-Swift/commit/18803f157c12e4c2d148dafd2a8ebd947c3cab5b))
     > Add a method &#x60;addNode&#x60; to allow adding nodes that contain subgraphs, and modify the existing stream processing logic to
     > handle embedded streams within these nodes. This enables more complex graph structures and parallel processing of multiple
     > data streams within a single node.
     > - Add &#x60;addNode&#x60; method to support subgraphs
     > - Modify stream processing to handle embedded streams within subgraph nodes
     > - Refactor some parts of the code for better readability and maintainability (Use arrow keys)
     > resolve #6 #7
   


### Documentation

 -  update readme ([9c8fa3aa612e5df](https://github.com/bsorrentino/LangGraph-Swift/commit/9c8fa3aa612e5df091ee63377fc62c120ab92dcb))

 -  add documentation to method addNode(String, StateGraph<State>.CompiledGraph) ([b61cad7a640f8c1](https://github.com/bsorrentino/LangGraph-Swift/commit/b61cad7a640f8c1020624b2cda79c0a80630fcb8))

 -  update package documentation ([808e4ea2015bace](https://github.com/bsorrentino/LangGraph-Swift/commit/808e4ea2015bace354aa408cd9bf3660ade9ef89))

 -  update changeme ([359731642c9d2df](https://github.com/bsorrentino/LangGraph-Swift/commit/359731642c9d2df78df7e3b21533aa9fc054b90c))


### Refactor

 -  add eternal package SwiftyACE, removing the local one ([7dc4588a0980d7d](https://github.com/bsorrentino/LangGraph-Swift/commit/7dc4588a0980d7ddcc2e577a154299e0f0e3095b))
   


### Test

 -  add subgraph test to validate state and message accumulation ([ff736b9aebfe44a](https://github.com/bsorrentino/LangGraph-Swift/commit/ff736b9aebfe44a0ec3a2033b0e5ad449fc35c4d))
    > The test covers various aspects such as:
 > - Ensuring all nodes in the subgraph are visited.
 > - Verifying the accumulation of messages across different levels of the subgraph.
 > - Confirming that the final state of the subgraph is correctly calculated by aggregating results from nested components.
 > work on #6 #7


### Continuous Integration

 -  add chanagelog generation script ([50c145701e46c8d](https://github.com/bsorrentino/LangGraph-Swift/commit/50c145701e46c8d022d207861c919fcd12e8b272))
   




<!-- "name: v3.1.0" is a release tag -->

## [v3.1.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v3.1.0) (2024-08-15)


### Bug Fixes

 -  add exclude argumant in target following the right sequence ([868d3a01fda16fa](https://github.com/bsorrentino/LangGraph-Swift/commit/868d3a01fda16fa9ea56b5b57037e49438b74ec1))


### Documentation

 -  update readme ([2887a29f0cd9dde](https://github.com/bsorrentino/LangGraph-Swift/commit/2887a29f0cd9dded3cfb4bf0ec07b134f168bc96))

 -  update package documentation ([ae397c1915e8402](https://github.com/bsorrentino/LangGraph-Swift/commit/ae397c1915e840222d0f9f41c3cd179b94f41aec))

 -  update package documentation ([47e4891c3b2a707](https://github.com/bsorrentino/LangGraph-Swift/commit/47e4891c3b2a707b7ed120fe5b62b95c394b2a85))

 -  update package documentation ([86de0d7f700b2b6](https://github.com/bsorrentino/LangGraph-Swift/commit/86de0d7f700b2b6ab9c85f3740ec9c0518ae2c0b))

 -  add generated docc documentation ([a3d1cc5c9b25d16](https://github.com/bsorrentino/LangGraph-Swift/commit/a3d1cc5c9b25d163f80a41b343b3dfdb948b7735))

 -  add code documentation ([9e6ce90efe8f0e7](https://github.com/bsorrentino/LangGraph-Swift/commit/9e6ce90efe8f0e7d603bf28064acc20b22dd16be))
     > add swift-docc-plugin

 -  update changeme ([2bb9383860337de](https://github.com/bsorrentino/LangGraph-Swift/commit/2bb9383860337decae7d6e07ef97e891c2487f5f))

 -  update changeme ([fffe6f16aee7e7c](https://github.com/bsorrentino/LangGraph-Swift/commit/fffe6f16aee7e7c3f31ed57e4103387252beb03a))


### Refactor

 -  **ChannelProtocol**  rename method  update to updateAttribute ([8203b8cfa63acc7](https://github.com/bsorrentino/LangGraph-Swift/commit/8203b8cfa63acc7e1a805cd9bb8ebc2ba9b67f58))
   
 -  add throws to DefaultProvider ([660bd6326678dec](https://github.com/bsorrentino/LangGraph-Swift/commit/660bd6326678dec6f79eea37a589a16273932255))
   

### ALM

 -  update exclude path ([aa5752b4f892652](https://github.com/bsorrentino/LangGraph-Swift/commit/aa5752b4f892652adf90cc47cedeb98660dfb05b))
   
 -  add changelog update shell ([7c4de5d36b0c4be](https://github.com/bsorrentino/LangGraph-Swift/commit/7c4de5d36b0c4be40008b1f905e1d286c1ee1f01))
   






<!-- "name: v3.0.2" is a release tag -->

## [v3.0.2](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v3.0.2) (2024-08-10)



### Documentation

 -  update readme ([14856ffa5338921](https://github.com/bsorrentino/LangGraph-Swift/commit/14856ffa53389213a7266e5add4bf3241149c3e1))

 -  update readme ([d950c0175d37343](https://github.com/bsorrentino/LangGraph-Swift/commit/d950c0175d373439c7abe16be6b6daf17600cc89))


### Refactor

 -  deprecate setEntryPoint, setConditionalEntryPoint and setFinishPoint ([286315d59dd9425](https://github.com/bsorrentino/LangGraph-Swift/commit/286315d59dd94256ae085b59260d7a05c9685681))
   







<!-- "name: v3.0.1" is a release tag -->

## [v3.0.1](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v3.0.1) (2024-08-05)



### Documentation

 -  update readme ([92354f0ea426863](https://github.com/bsorrentino/LangGraph-Swift/commit/92354f0ea426863e310a0241c356cef79006cd99))

 -  update changelog ([aa46ca9085224fa](https://github.com/bsorrentino/LangGraph-Swift/commit/aa46ca9085224faf7b15c43bcf0258c866a1f245))


### Refactor

 -  rename param name 'schema' to 'channels' ([1f449590227b3e8](https://github.com/bsorrentino/LangGraph-Swift/commit/1f449590227b3e8595a196510b98dc5e6fdf34df))
    > langgraph.js compliance

 -  rename param name 'schema' to 'channels' ([49a8a0a246ae707](https://github.com/bsorrentino/LangGraph-Swift/commit/49a8a0a246ae707f3539974791cadcc2209e3cc9))
    > langgraph.js compliance








<!-- "name: v3.0.0" is a release tag -->

## [v3.0.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v3.0.0) (2024-08-04)

### Features

 *  finalize Status Schema Management ([0858b51d0ccb87a](https://github.com/bsorrentino/LangGraph-Swift/commit/0858b51d0ccb87a5c22908796f9b4b48b0007880))
     > refine Channel class
     > update Demo
     > refine unit test
   
 *  refine Channels management ([74a4768633e8caf](https://github.com/bsorrentino/LangGraph-Swift/commit/74a4768633e8cafab52940a2e75515e1afac5a2b))
     > introducing State Schema concept
   
 *  add EvaluableValueProtocol ([8d6f2aabd87333e](https://github.com/bsorrentino/LangGraph-Swift/commit/8d6f2aabd87333ea445088e75f7cea80a5993596))
   


### Documentation

 -  update readme ([30930184adf2608](https://github.com/bsorrentino/LangGraph-Swift/commit/30930184adf2608964f1f0c905c60d4a7b7a4491))

 -  update changelog ([9ae23b4f4b46147](https://github.com/bsorrentino/LangGraph-Swift/commit/9ae23b4f4b46147487c1b03c6cbad985216d67b4))


### Refactor

 -  add channel management in AgentState ([2e96e05793f1748](https://github.com/bsorrentino/LangGraph-Swift/commit/2e96e05793f1748c44c7981c774fe91899019c6b))
   







<!-- "name: v2.0.1" is a release tag -->

## [v2.0.1](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v2.0.1) (2024-07-09)


### Bug Fixes

 -  support for custom description in custom error ([45e5243ee116326](https://github.com/bsorrentino/LangGraph-Swift/commit/45e5243ee11632614908caef34432629278591a0))


### Documentation

 -  update changelog ([4ed6e09126b2ca0](https://github.com/bsorrentino/LangGraph-Swift/commit/4ed6e09126b2ca01c3e8168c86b1eff284e6ea3e))









<!-- "name: v2.0.0" is a release tag -->

## [v2.0.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v2.0.0) (2024-07-08)

### Features

 *  add setConditionalEntryPoint method ([d870c296b8c73f0](https://github.com/bsorrentino/LangGraph-Swift/commit/d870c296b8c73f03bb3e667142badca2a95b4773))
     > resolve #3
   


### Documentation

 -  update readme ([3cbe0fa5f9bde5f](https://github.com/bsorrentino/LangGraph-Swift/commit/3cbe0fa5f9bde5fa28d63ed4dc9aa34c2e4e7a74))

 -  update changelog ([313a953020673c1](https://github.com/bsorrentino/LangGraph-Swift/commit/313a953020673c162dfa6b8d1f76d78ce4930d2c))


### Refactor

 -  **tests**  update class names ([61edc7ce9e51acc](https://github.com/bsorrentino/LangGraph-Swift/commit/61edc7ce9e51acc4d933da112443dae358db6847))
   
 -  **AgentExecutor**  apply new names ([2a1e495e4874c33](https://github.com/bsorrentino/LangGraph-Swift/commit/2a1e495e4874c33c4abfdd5d65153571a838c6c0))
   
 -  **langgraph**  rename Errors enum ([2414f647631d331](https://github.com/bsorrentino/LangGraph-Swift/commit/2414f647631d3315d54c90857cceffc8a0ce9969))
   
 -  rename classes ([0800db80be61009](https://github.com/bsorrentino/LangGraph-Swift/commit/0800db80be61009e211bc9e79a90dfa1db77110e))
    > GraphState -&gt; StateGraph
 > Runner -&gt; CompiledGraph








<!-- "name: v1.2.2" is a release tag -->

## [v1.2.2](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.2.2) (2024-04-20)

### Features

 *  enabletyped  AppendableValue ([995a3e9295957cf](https://github.com/bsorrentino/LangGraph-Swift/commit/995a3e9295957cffebb0784bea342375308d1785))
   


### Documentation

 -  update readme ([245213881528d9a](https://github.com/bsorrentino/LangGraph-Swift/commit/245213881528d9a8867d85939f1e168e53b705c2))

 -  update changelog ([5d49eeef8bd6a96](https://github.com/bsorrentino/LangGraph-Swift/commit/5d49eeef8bd6a96b88115036dc4bd93f71eab2ef))


### Refactor

 -  use switch expression ([4062b742904d668](https://github.com/bsorrentino/LangGraph-Swift/commit/4062b742904d66819d4a4fb63e6a3aeff7692896))
   







<!-- "name: v1.2.1" is a release tag -->

## [v1.2.1](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.2.1) (2024-03-19)


### Bug Fixes

 -  handle process interruption on invoke ([8d340c46bd88347](https://github.com/bsorrentino/LangGraph-Swift/commit/8d340c46bd88347817bd074a171bc3ca46fd759d))


### Documentation

 -  update changelog ([7f7b2ef63e14957](https://github.com/bsorrentino/LangGraph-Swift/commit/7f7b2ef63e14957596cac7d7fc705cf294c05a99))









<!-- "name: v1.2.0" is a release tag -->

## [v1.2.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.2.0) (2024-03-19)

### Features

 *  check for task cancellation ([6167de22f904b26](https://github.com/bsorrentino/LangGraph-Swift/commit/6167de22f904b2697e6a4ec5fbe77ea25a866a6d))
     > resolve  #2
   


### Documentation

 -  update changelog ([185f938d61a8659](https://github.com/bsorrentino/LangGraph-Swift/commit/185f938d61a8659b688907d1906d2b7ba231e545))


### Refactor

 -  update error message ([e2c26b224338497](https://github.com/bsorrentino/LangGraph-Swift/commit/e2c26b22433849786e374e16124995a2c6d29cca))
   







<!-- "name: v1.1.0" is a release tag -->

## [v1.1.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.1.0) (2024-03-17)

### Features

 *  add support of streaming result ([7814bc9aa5b14fc](https://github.com/bsorrentino/LangGraph-Swift/commit/7814bc9aa5b14fc213477f4ea000b4ebfeda2ecb))
     > create a new struct NodeOutput
     > use of AsyncThrowingStream
     > add unit test
     > resolve #1
   
 *  add swift-async-algorithms package ([220b164840bd090](https://github.com/bsorrentino/LangGraph-Swift/commit/220b164840bd090da0d805080dfb2240e514ad0b))
     > work on #1
   

### Bug Fixes

 -  update NodeOutput access control ([b8369a2b6bea65f](https://github.com/bsorrentino/LangGraph-Swift/commit/b8369a2b6bea65f8779e2d2bb24065294557a362))
     > work on #1

 -  invalidate and remove apikey ([1b2b74bd7074e01](https://github.com/bsorrentino/LangGraph-Swift/commit/1b2b74bd7074e01c6ddb971bf86471c7dce69ceb))

 -  update git url in changelog templete ([81645f47528852e](https://github.com/bsorrentino/LangGraph-Swift/commit/81645f47528852e449a1cbe4af3be41ae73c895a))


### Documentation

 -  update readme ([cc480ba9aa94094](https://github.com/bsorrentino/LangGraph-Swift/commit/cc480ba9aa9409445cf01842da167e42c70e87dc))

 -  update reademe ([1dcd0a2e204c2a1](https://github.com/bsorrentino/LangGraph-Swift/commit/1dcd0a2e204c2a18b885792d9777ab2d02717320))

 -  update reademe ([79ac1356e4b4064](https://github.com/bsorrentino/LangGraph-Swift/commit/79ac1356e4b40646fc7dab1bd5ddba1d7625e872))

 -  update reademe ([59c4d768161d98a](https://github.com/bsorrentino/LangGraph-Swift/commit/59c4d768161d98ab539ed57f11470a14b7dad92f))

 -  add changelog ([2774af3b8f25915](https://github.com/bsorrentino/LangGraph-Swift/commit/2774af3b8f25915f710439db7e4009179a3c83c4))


### Refactor

 -  remove swift-async-algorithms deps ([fa06c7d8ba3e2fc](https://github.com/bsorrentino/LangGraph-Swift/commit/fa06c7d8ba3e2fcdffd6467dba64020fd354f9b5))
    > work on #1



### Test

 -  update demo project to use stream ([bf03689998ab329](https://github.com/bsorrentino/LangGraph-Swift/commit/bf03689998ab329e91f01871a15a991b59ae23d2))
    > work on #1






<!-- "name: v1.0.0" is a release tag -->

## [v1.0.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.0.0) (2024-03-16)

### Features

 *  complete refactory on LangChain AgentExecutor in LangGraph ([32b460cbd5db3ec](https://github.com/bsorrentino/LangGraph-Swift/commit/32b460cbd5db3ecf9b399d58c60375391efa8bf0))
   
 *  add AppendableValue for managing AgentState property array ([4cb667e920d29dc](https://github.com/bsorrentino/LangGraph-Swift/commit/4cb667e920d29dc8c1a2bdb590b9faac7c4413aa))
   
 *  setup langchain demo app project ([c0bdcb96b32621a](https://github.com/bsorrentino/LangGraph-Swift/commit/c0bdcb96b32621a724b88efb47020766d649b855))
   
 *  initial import ([f90ad82a6ceab98](https://github.com/bsorrentino/LangGraph-Swift/commit/f90ad82a6ceab98928d9132172fde72179075ea0))
     > add a base LangGraph implmentation + unit tests
   


### Documentation

 -  update readme ([ef5ba26153d6ae6](https://github.com/bsorrentino/LangGraph-Swift/commit/ef5ba26153d6ae6cca8933ed3837adcb12daf0b4))


### Refactor

 -  pass a State Factory instead of State Type ([17b16a590f99789](https://github.com/bsorrentino/LangGraph-Swift/commit/17b16a590f9978947ce730fd8fc774092b12109f))
   
 -  start porting LangChain agent to LangGraph ([d829826d94b9c0e](https://github.com/bsorrentino/LangGraph-Swift/commit/d829826d94b9c0e0c9b414ed419e99d550cb5979))
   

### ALM

 -  add changelog script ([6ab450b9029ab20](https://github.com/bsorrentino/LangGraph-Swift/commit/6ab450b9029ab20b327e82ffaeb2ad07d07891ce))
   




