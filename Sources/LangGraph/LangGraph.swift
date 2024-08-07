import OSLog

public typealias PartialAgentState = [String: Any]
public typealias NodeAction<Action: AgentState> = ( Action ) async throws -> PartialAgentState
public typealias EdgeCondition<Action: AgentState> = ( Action ) async throws -> String

public typealias Reducer<Value> = ( Value?, Value ) -> Value
public typealias DefaultProvider<Value> = () -> Value

public typealias StateFactory<State: AgentState> = ( [String: Any] ) -> State

public protocol ChannelProtocol {
    associatedtype T
    var reducer: Reducer<T>? {  get }
    var `default`: DefaultProvider<T>? { get }

    func update( oldValue: Any?, newValue: Any ) throws -> Any
}


public class Channel<T> : ChannelProtocol {
    public var reducer: Reducer<T>?
    public var `default`: DefaultProvider<T>?
    
    public init(reducer: Reducer<T>? = nil, default defaultValueProvider: DefaultProvider<T>? = nil ) {
        self.reducer = reducer
        self.`default` = defaultValueProvider
    }
    
    public func update( oldValue: Any?, newValue: Any ) throws -> Any {
        guard let new = newValue as? T else {
            throw CompiledGraphError.executionError( "Channel update 'newValue' type mismatch!")
        }

        var old:T?
        if oldValue == nil {
            if let `default` {
                old = `default`()
            }
        }
        else {
            guard let _old = oldValue as? T else {
                throw CompiledGraphError.executionError( "Channel update 'oldValue' type mismatch!")
            }
            old = _old
        }

        if let reducer {
            return reducer( old, new )
        }
        return new

    }
}

public class AppenderChannel<T> : Channel<[T]> {
        
    public init( default defaultValueProvider: @escaping DefaultProvider<[T]> = { [] } ) {
        super.init()
        self.reducer = { left, right in
        
            guard var left else {
                return right
            }
            
            left.append(contentsOf: right)
            return left
        }
        self.default = defaultValueProvider
    }
    
    public override func update( oldValue: Any?, newValue: Any ) throws -> Any {
        if let new = newValue as? T {
            return try super.update(oldValue: oldValue, newValue: [new] )
        }
        return try super.update(oldValue: oldValue, newValue: newValue )
    }

}

public typealias Channels = [String: any ChannelProtocol ]

public protocol AgentState {
    
    var data: [String: Any] { get }
    
//    subscript(key: String) -> Any? { get }
    
    init( _ initState: [String: Any] )
}

extension AgentState {

    public func value<T>( _ key: String ) -> T? {
        return data[ key ] as? T
        
    }
    
}

public struct NodeOutput<State: AgentState> {
    public var node: String
    public var state: State
    
    public init(node: String, state: State) {
        self.node = node
        self.state = state
    }
}


public struct BaseAgentState : AgentState {
    
    public subscript(key: String) -> Any? {
        value( key )
    }
    
    public var data: [String : Any]
    
    public init() {
        data = [:]
    }
    
    public init(_ initState: [String : Any]) {
        data = initState
    }
    
    
}
public enum StateGraphError : Error, LocalizedError {
    case duplicateNodeError( String )
    case duplicateEdgeError( String )
    case missingEntryPoint
    case entryPointNotExist( String )
    case finishPointNotExist( String )
    case missingNodeInEdgeMapping( String )
    case edgeMappingIsEmpty
    case invalidEdgeIdentifier( String )
    case invalidNodeIdentifier( String )
    case missingNodeReferencedByEdge( String )
    
    public var errorDescription: String? {
        switch(self) {
        case .duplicateNodeError(let message):
            message
        case .duplicateEdgeError(let message):
            message
        case .missingEntryPoint:
            "missing entry point!"
        case .entryPointNotExist(let message):
            message
        case .finishPointNotExist(let message):
            message
        case .missingNodeInEdgeMapping(let message):
            message
        case .edgeMappingIsEmpty:
            "edge mapping is empty!"
        case .invalidNodeIdentifier(let message):
            message
        case .missingNodeReferencedByEdge(let message):
            message
        case .invalidEdgeIdentifier(let message):
            message
        }
    }

}

public enum CompiledGraphError : Error, LocalizedError {
    case missingEdge( String )
    case missingNode( String )
    case missingNodeInEdgeMapping( String )
    case executionError( String )
    
    public var errorDescription: String? {
        switch(self) {
        case .missingEdge(let message):
            message
        case .missingNode(let message):
            message
        case .missingNodeInEdgeMapping(let message):
            message
        case .executionError(let message):
            message
        }
    }
}

public let END = "__END__" // id of the edge ending workflow

//enum Either<Left, Right> {
//    case left(Left)
//    case right(Right)
//}

let log = Logger( subsystem: Bundle.module.bundleIdentifier ?? "langgraph", category: "main")

public class StateGraph<State: AgentState>  {
    
    enum EdgeValue /* Union */ {
        case id(String)
        case condition( ( EdgeCondition<State>, [String:String] ) )
    }
    
    public class CompiledGraph {
    
        var stateFactory: StateFactory<State>
        var nodes:Dictionary<String, NodeAction<State>>
        var edges:Dictionary<String, EdgeValue>
        var entryPoint:EdgeValue
        var finishPoint:String?
        let schema: Channels
        
        init( owner: StateGraph ) {
            self.schema = owner.channels
            self.stateFactory = owner.stateFactory
            self.nodes = Dictionary()
            self.edges = Dictionary()
            self.entryPoint = owner.entryPoint!
            self.finishPoint = owner.finishPoint
            
            owner.nodes.forEach { [unowned self] node in
                nodes[node.id] = node.action
            }
            
            owner.edges.forEach { [unowned self] edge in
                edges[edge.sourceId] = edge.target
            }
        }
        
        private func initStateDataFromSchema() -> [String: Any] {
            let mappedValues = schema.compactMap { key, channel in
                if let def = channel.`default` {
                    return ( key, def() )
                }
                return nil
            }
            
            return Dictionary(uniqueKeysWithValues: mappedValues)
        }
        
        private func updatePartialStateFromSchema( currentState: State, partialState: PartialAgentState ) throws -> PartialAgentState {
            let mappedValues  = try partialState.map { key, value in
                if let channel = schema[key] {
                    
                    do {
                        let newValue = try channel.update( oldValue: currentState.data[key], newValue: value )
                        return ( key, newValue )
                    }
                    catch CompiledGraphError.executionError( let message ){
                        throw CompiledGraphError.executionError( "error processing property: '\(key)' - \(message)")
                    }
                    
                }
                return (key, value)
            }
            
            return Dictionary( uniqueKeysWithValues: mappedValues)

        }
        
        private func mergeState( currentState: State, partialState: PartialAgentState ) throws -> State {
            if partialState.isEmpty {
                return currentState
            }
            
            let partialSchemaUpdated = try updatePartialStateFromSchema( currentState: currentState, partialState: partialState)
            
            let newState = currentState.data.merging(partialSchemaUpdated, uniquingKeysWith: {
                (current, new) in
                                
                return new
            })
            return State.init(newState)
        }
        
        private func nextNodeId( route: EdgeValue?, agentState: State, nodeId: String ) async throws -> String {
            
            guard let route else {
                throw CompiledGraphError.missingEdge("edge with node: \(nodeId) not found!")
            }
            
            switch( route ) {
            case .id( let nextNodeId ):
                return nextNodeId
            case .condition( let (condition, mapping)):
                
                let newRoute = try await condition( agentState )
                guard let result = mapping[newRoute] else {
                    throw CompiledGraphError.missingNodeInEdgeMapping("cannot find edge mapping for id: \(newRoute) in conditional edge with sourceId:\(nodeId) ")
                }
                return result
            }
        }

        private func nextNodeId( nodeId: String, agentState: State ) async throws -> String {
            try await nextNodeId(route: edges[nodeId], agentState: agentState, nodeId: nodeId)
        }
        private func getEntryPoint( agentState: State ) async throws -> String {
            try await nextNodeId( route: self.entryPoint, agentState: agentState, nodeId: "entryPoint" )
        }

        public func stream( inputs: PartialAgentState, verbose:Bool = false ) -> AsyncThrowingStream<NodeOutput<State>, Error> {
            
            let (stream, continuation) = AsyncThrowingStream.makeStream(of: NodeOutput<State>.self, throwing: Error.self)
            
            Task {
                
                do {
                
                    let initData = initStateDataFromSchema()
                    
                    var currentState = try mergeState( currentState: self.stateFactory( initData ), partialState: inputs)
                    
                    var currentNodeId = try await self.getEntryPoint(agentState: currentState )

                    repeat {
                        
                        guard let action = nodes[currentNodeId] else {
                            continuation.finish(throwing: CompiledGraphError.missingNode("node: \(currentNodeId) not found!") )
                            break
                        }
                        
                        if( verbose ) {
                            log.debug("start processing node \(currentNodeId)")
                        }
                        
                        try Task.checkCancellation()
                        let partialState = try await action( currentState )
                        
                        currentState = try mergeState( currentState: currentState, partialState: partialState)
                        
                        let output = NodeOutput(node: currentNodeId,state: currentState)
                        
                        try Task.checkCancellation()
                        continuation.yield( output )

                        if( currentNodeId == finishPoint ) {
                            break
                        }
                        
                        currentNodeId = try await nextNodeId(nodeId: currentNodeId, agentState: currentState)
                        
                    } while( currentNodeId != END && !Task.isCancelled )
                    
                    continuation.finish()
                }
                catch {
                    continuation.finish(throwing: error)
                }
            }
            
            return stream
        }
        
        
        /// run the graph an return the final State
        ///
        /// - Parameters:
        ///   - inputs: partial state
        ///   - verbose: enable verbose output (log)
        /// - Returns: final State
        public func invoke( inputs: PartialAgentState, verbose:Bool = false ) async throws -> State {
            
            let initResult:[NodeOutput<State>] = []
            let result = try await stream(inputs: inputs).reduce( initResult, { partialResult, output in
                [output]
            })
            if result.isEmpty {
                throw CompiledGraphError.executionError("no state has been produced! probably processing has been interrupted")
            }
            return result[0].state
        }
    }

    struct Edge : Hashable, Identifiable{
        var id: String {
            sourceId
        }
        static func == (lhs: StateGraph.Edge, rhs: StateGraph.Edge) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
        
        var sourceId:String
        var target:EdgeValue
        
    }

    private var edges: Set<Edge> = []
    
    struct Node : Hashable, Identifiable {
        static func == (lhs: StateGraph.Node, rhs: StateGraph.Node) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
        
        var id: String
        var action: NodeAction<State>
    }
    
    private var nodes: Set<Node> = []

    private var entryPoint: EdgeValue?
    private var finishPoint: String?

    private var stateFactory: StateFactory<State>
    private var channels: Channels
    
    public init( channels: Channels = [:], stateFactory: @escaping StateFactory<State> ) {
        self.channels = channels
        self.stateFactory = stateFactory
            
    }
    
    public func addNode( _ id: String, action: @escaping NodeAction<State> ) throws {
        guard id != END else {
            throw StateGraphError.invalidNodeIdentifier( "END is not a valid node id!")
        }
        let node = Node(id: id,action: action)
        if nodes.contains(node) {
            throw StateGraphError.duplicateNodeError("node with id:\(id) already exist!")
        }
        nodes.insert( node )
        
    }
    public func addEdge( sourceId: String, targetId: String ) throws {
        guard sourceId != END else {
            throw StateGraphError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }

        let edge = Edge(sourceId: sourceId, target: .id(targetId) )
        if edges.contains(edge) {
            throw StateGraphError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge )
    }
    public func addConditionalEdge( sourceId: String, condition: @escaping EdgeCondition<State>, edgeMapping: [String:String] ) throws {
        guard sourceId != END else {
            throw StateGraphError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }
        if edgeMapping.isEmpty {
            throw StateGraphError.edgeMappingIsEmpty
        }

        let edge = Edge(sourceId: sourceId, target: .condition(( condition, edgeMapping)) )
        if edges.contains(edge) {
            throw StateGraphError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge)
    }
    public func setEntryPoint( _ nodeId: String ) throws {
        guard nodeId != END else {
            throw StateGraphError.invalidNodeIdentifier( "END is not a valid node entry point!")
        }
        entryPoint = EdgeValue.id(nodeId)
    }
    public func setConditionalEntryPoint( condition: @escaping EdgeCondition<State>, edgeMapping: [String:String] ) throws {
        if edgeMapping.isEmpty {
            throw StateGraphError.edgeMappingIsEmpty
        }
        entryPoint = EdgeValue.condition((condition, edgeMapping))
    }
    public func setFinishPoint( _ nodeId: String ) {
        finishPoint = nodeId
    }
    
    private var fakeAction:NodeAction<State> = { _ in  return [:] }

    private func makeFakeNode( _ id: String ) -> Node {
        Node(id: id, action: fakeAction)
    }
    
    public func compile() throws -> CompiledGraph {
        guard let entryPoint else {
            throw StateGraphError.missingEntryPoint
        }
        
        switch( entryPoint ) {
            case .id( let targetId ):
                guard nodes.contains( makeFakeNode( targetId ) ) else {
                    throw StateGraphError.entryPointNotExist( "entryPoint: \(targetId) doesn't exist!")
                }
            break
            case .condition((_, let edgeMappings)):
                for (_,nodeId) in edgeMappings {
                    guard nodeId==END || nodes.contains(makeFakeNode(nodeId) ) else {
                        throw StateGraphError.missingNodeInEdgeMapping( "edge mapping for entryPoint contains a not existent nodeId \(nodeId)!")
                    }
                }
            break
        }
        
        if let finishPoint {
            guard nodes.contains( makeFakeNode( finishPoint ) ) else {
                throw StateGraphError.finishPointNotExist( "finishPoint: \(finishPoint) doesn't exist!")
            }
        }
        // TODO check edges
        for edge in edges {
            
            guard nodes.contains( makeFakeNode(edge.sourceId) ) else {
                throw StateGraphError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId) reference to non existent node!")
            }

            switch( edge.target ) {
            case .id( let targetId ):
                guard targetId==END || nodes.contains(makeFakeNode(targetId) ) else {
                    throw StateGraphError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId)  reference to non existent node targetId: \(targetId) node!")
                }
                break
            case .condition((_, let edgeMappings)):
                for (_,nodeId) in edgeMappings {
                    guard nodeId==END || nodes.contains(makeFakeNode(nodeId) ) else {
                        throw StateGraphError.missingNodeInEdgeMapping( "edge mapping for sourceId: \(edge.sourceId) contains a not existent nodeId \(nodeId)!")
                    }
                }
            }
        }
        
        return CompiledGraph( owner: self )
    }
}
