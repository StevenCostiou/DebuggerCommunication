Class {
	#name : #DebuggerCommunicationTest,
	#superclass : #TestCase,
	#instVars : [
		'dbg',
		'dbgServer',
		'dbgp',
		'dbgl',
		'dbgc'
	],
	#category : #'DebuggerCommunication-Tests'
}

{ #category : #tests }
DebuggerCommunicationTest >> areExecutionsAtTheSamePoint [
	^ (self serialiseMaterialise: dbgl node) = dbgp node
]

{ #category : #tests }
DebuggerCommunicationTest >> execBlock_failingTest [
	| testInstance |
	testInstance := FodderForDebuggerCommunicationTest new.
	^ [ testInstance testFails ].
]

{ #category : #tests }
DebuggerCommunicationTest >> execBlock_passingTest [
	| testInstance |
	testInstance := FodderForDebuggerCommunicationTest new.
	^ [ testInstance testPasses ].
]

{ #category : #tests }
DebuggerCommunicationTest >> execBlock_pointCreation [
	^ [ Point x: 1 y: 2 ]
]

{ #category : #tests }
DebuggerCommunicationTest >> execBlock_signalError [
	^ [ Error signal: 'test error' ]
]

{ #category : #'as yet unclassified' }
DebuggerCommunicationTest >> serialiseMaterialise: anObject [
	"When getting an object from the local sindarin debugger, it cannot be compared directly to the equivalent object obtained from the remote sindarin debugger, because the latter may have been changed by the serialisation and materialisation it underwent. To compensate this, we need to also serialise and materialise the object from the local debugger."
	^ dbgc materialise: (dbgServer serialise: anObject)
]

{ #category : #running }
DebuggerCommunicationTest >> setUp [
	"Hooks that subclasses may override to define the fixture of test."
]

{ #category : #'as yet unclassified' }
DebuggerCommunicationTest >> setUpOnBlock: aBlock [
	| port |
	port := 8249.
	
	"Debugger on the local execution"
	dbgl := SindarinDebugger debug: aBlock.
	
	"Debugger on the remotely-controlled execution"
	dbg := SindarinDebugger debug: aBlock.
	dbgServer := SindarinDebuggerServer newOnSindarinDebugger: dbg.
	dbgServer startListeningOnPort: port.
	
	"Proxy debugger on the debugger controlling the remotely-controlled execution"
	dbgc := SindarinDebuggerClient newOnPort: port.
	dbgp := SindarinDebuggerProxyClient newOnSindarinDebuggerClient: dbgc.
]

{ #category : #running }
DebuggerCommunicationTest >> tearDown [
	"Hooks that subclasses may override to clean the fixture of test."
	dbgServer stop.
]

{ #category : #tests }
DebuggerCommunicationTest >> testExecutionIsFinished [
	"Tests that the end of the execution is correctly detected by the remote execution"
	self setUpOnBlock: self execBlock_pointCreation.
	
	[dbgl isExecutionFinished | dbgp isExecutionFinished ] whileFalse: [ 
		dbgl step.
		dbgp step
	].
	"If one execution finished, both must have finished"
	"This assertion fails because both execution arrived on the call to ProcessorScheduler>>#terminateActive, but the remote execution has a step hook to finish that call in one go, so it finishes it without the local execution doing any step. After that, the remote execution answer true to #isExecutionFinished, but not the local one"
	self assert: dbgl isExecutionFinished & dbgp isExecutionFinished.
	self assert: self areExecutionsAtTheSamePoint.
	
]

{ #category : #tests }
DebuggerCommunicationTest >> testRemoteExecutionIsPassingTest [

	| nodes |
	self setUpOnBlock: self execBlock_passingTest.
	
	nodes := OrderedCollection new.
	[ dbgp isExecutionFinished ] whileFalse: [ nodes add: dbgp node. dbgp step ].
	self halt.

	
]

{ #category : #tests }
DebuggerCommunicationTest >> testRemoteExecutionSignalsError [

	| nodes |
	self setUpOnBlock: self execBlock_signalError.

	nodes := OrderedCollection new.
	self should: [[ true ] whileTrue: [ nodes add: dbgp node. dbgp step ]] raise: Error.

	
]

{ #category : #tests }
DebuggerCommunicationTest >> testRemoteExecutionSignalsTestFailure [

	| nodes |
	self setUpOnBlock: self execBlock_failingTest.
	
	nodes := OrderedCollection new.
	[ dbgp isExecutionFinished ] whileFalse: [ nodes add: dbgp node. dbgp step ].

	
]

{ #category : #tests }
DebuggerCommunicationTest >> testSameAfterStep [
	"Tests that after a step, the local and remotely-controlled execution are at the same point"
	self setUpOnBlock: self execBlock_pointCreation.
	
	dbgl step.
	dbgp step.
	self assert: self areExecutionsAtTheSamePoint
]

{ #category : #tests }
DebuggerCommunicationTest >> testSameStart [
	"Test that both the local and remotely-controlled execution start at the same point"
	self setUpOnBlock: self execBlock_pointCreation.
	
	self assert: self areExecutionsAtTheSamePoint.
]

{ #category : #tests }
DebuggerCommunicationTest >> testSerialiseASTNode [
	| astNodeRepresentation |
	self setUpOnBlock: self execBlock_pointCreation.
	
	astNodeRepresentation := dbgc sendRequest: TestRequestReturnASTNode new.
	self assert: (astNodeRepresentation at: #source) equals: 'self myMessage: 25'.
	self assert: (astNodeRepresentation at: #class) equals: 'TestRequestReturnASTNode'.
	self assert: (astNodeRepresentation at: #nodeType) equals: 'RBMessageNode'.
	self assert: (astNodeRepresentation at: #stop) equals: 30.
	self assert: (astNodeRepresentation at: #start) equals: 13.
	self assert: (astNodeRepresentation at: #methodSourceCode) equals: 'testMethod
	self myMessage: 25'.
	self assert: (astNodeRepresentation at: #methodSelector) equals: #testMethod.
]

{ #category : #tests }
DebuggerCommunicationTest >> testSerialiseBlockClosure [
	| blockClosure |
	"Serialising a BlockClosure does not work at the moment"
	self setUpOnBlock: self execBlock_pointCreation.	
	
	blockClosure := dbgc sendRequest: TestRequestReturnBlockClosure new.
	self assert: blockClosure value equals: 42.
]

{ #category : #tests }
DebuggerCommunicationTest >> testSerialiseContext [
	| contextRepresentation nodeRepresentation selectorOfMethodContainingBlockToDebug |
	selectorOfMethodContainingBlockToDebug := #execBlock_pointCreation.
	self setUpOnBlock: (self perform: selectorOfMethodContainingBlockToDebug).
	
	contextRepresentation := dbgc sendRequest: TestRequestReturnContext new.
	self assert: (contextRepresentation at: #receiver) equals: 'DebuggerCommunicationTest>>#testSerialiseContext'.
	self assert: (contextRepresentation at: #method) equals: (self class >>selectorOfMethodContainingBlockToDebug) sourceCode.
	self assert: (contextRepresentation at: #selector) equals: selectorOfMethodContainingBlockToDebug.
	nodeRepresentation := contextRepresentation at: #node.
	self assert: (nodeRepresentation at: #source) equals: 'Point x: 1 y: 2'.
	self assert: (nodeRepresentation at: #nodeType) equals: 'RBMessageNode'.
]

{ #category : #tests }
DebuggerCommunicationTest >> testSerialiseInteger [
	self setUpOnBlock: self execBlock_pointCreation.

	self assert: (dbgc sendRequest: TestRequestReturnFive new) equals: 5.
]
