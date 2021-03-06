Extension { #name : #RBProgramNode }

{ #category : #'*DebuggerCommunication' }
RBProgramNode >> dictionaryRepresentation [
	| dict |
	dict := RBProgramNodeRepresentation new.
	dict at: #start put: self start.
	dict at: #stop put: self stop.
	dict at: #methodSelector put: self methodNode selector.
	dict at: #nodeType put: self class asString.
	dict at: #class put: self methodNode methodClass asString.
	dict at: #methodSourceCode put: self source.
	dict at: #source put: self sourceCode.
	"stonWriter writeString: 'RBProgramNode'."
	^ dict
]

{ #category : #'*DebuggerCommunication' }
RBProgramNode >> stonOn: stonWriter [
	| dict |
	dict := self dictionaryRepresentation.
	dict stonOn: stonWriter.
]
