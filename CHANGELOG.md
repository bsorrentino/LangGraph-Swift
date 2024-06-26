# Changelog


"name: v1.2.2" is a release tag

## [v1.2.2](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.2.2) (2024-04-20)

### Features

 *  enabletyped  AppendableValue ([995a3e9295957cf](https://github.com/bsorrentino/LangGraph-Swift/commit/995a3e9295957cffebb0784bea342375308d1785))
   


### Documentation

 -  update readme ([245213881528d9a](https://github.com/bsorrentino/LangGraph-Swift/commit/245213881528d9a8867d85939f1e168e53b705c2))

 -  update changelog ([5d49eeef8bd6a96](https://github.com/bsorrentino/LangGraph-Swift/commit/5d49eeef8bd6a96b88115036dc4bd93f71eab2ef))


### Refactor

 -  use switch expression ([4062b742904d668](https://github.com/bsorrentino/LangGraph-Swift/commit/4062b742904d66819d4a4fb63e6a3aeff7692896))




"name: v1.2.1" is a release tag

## [v1.2.1](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.2.1) (2024-03-19)


### Bug Fixes

 -  handle process interruption on invoke ([8d340c46bd88347](https://github.com/bsorrentino/LangGraph-Swift/commit/8d340c46bd88347817bd074a171bc3ca46fd759d))


### Documentation

 -  update changelog ([7f7b2ef63e14957](https://github.com/bsorrentino/LangGraph-Swift/commit/7f7b2ef63e14957596cac7d7fc705cf294c05a99))





"name: v1.2.0" is a release tag

## [v1.2.0](https://github.com/bsorrentino/LangGraph-Swift/releases/tag/v1.2.0) (2024-03-19)

### Features

 *  check for task cancellation ([6167de22f904b26](https://github.com/bsorrentino/LangGraph-Swift/commit/6167de22f904b2697e6a4ec5fbe77ea25a866a6d))
     > resolve  #2
   


### Documentation

 -  update changelog ([185f938d61a8659](https://github.com/bsorrentino/LangGraph-Swift/commit/185f938d61a8659b688907d1906d2b7ba231e545))


### Refactor

 -  update error message ([e2c26b224338497](https://github.com/bsorrentino/LangGraph-Swift/commit/e2c26b22433849786e374e16124995a2c6d29cca))




"name: v1.1.0" is a release tag

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




"name: v1.0.0" is a release tag

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


