import Foundation

/// Represents a checkpoint of an agent state.
///
/// The checkpoint is an immutable object that holds an agent state
/// and a string that represents the next state.
/// It is designed to be serializable and restorable.
public struct Checkpoint {
    let id: UUID
    var state: [String: Any]
    var nodeId: String
    var nextNodeId: String
    
    public init(state: [String: Any], nodeId: String, nextNodeId: String) {
        self.id = UUID()
        self.state = state
        self.nodeId = nodeId
        self.nextNodeId = nextNodeId
    }

    mutating func updateState(values: [String: Any], channels: Channels) throws {
        
        self.state = try LangGraph.updateState(currentState: self.state , partialState: values , channels: channels)
    }
}

public struct Tag {
    var threadId: String
    var checkpoints: [Checkpoint]
}


public protocol CheckpointSaver {
    
    func list(config: RunnableConfig) -> AnyCollection<Checkpoint>;

    func get(config: RunnableConfig) ->  Checkpoint?;

    func put(config: RunnableConfig,  checkpoint: Checkpoint) throws -> RunnableConfig;

    func release(config: RunnableConfig) throws -> Tag;

}

extension CheckpointSaver {
    @inline(__always) func THREAD_ID_DEFAULT() -> String { "$default" };
}

struct Stack<T>  {
    var elements: [T] = []

    var isEmpty: Bool {
        return elements.isEmpty
    }

    var count: Int {
        return elements.count
    }

    mutating func push(_ value: T) {
        elements.append(value)
    }

    mutating func pop() -> T? {
        return elements.popLast()
    }

    func peek() -> T? {
        return elements.last
    }
}

extension Stack: Sequence {
    public func makeIterator() -> IndexingIterator<Array<T>> {
        return elements.makeIterator()
    }
}

extension Stack {
    
    subscript(id: UUID) -> T? where T == Checkpoint {
        get {
            return elements.first { $0.id == id }
        }
        set(newValue) {
            guard let newValue else {
                fatalError( "Cannot set checkpoint with id \(id) to nil")
            }
            
            guard let index = elements.firstIndex(where: { $0.id == id }) else {
                fatalError( "Cannot find checkpoint with id \(id)" )
            }
            
            elements[index] = newValue
        }
    }
}

public class MemoryCheckpointSaver: CheckpointSaver {
    var checkpointsByThread: [String: Stack<Checkpoint>] = [:];
    
    private func checkpoints(config: RunnableConfig ) -> Stack<Checkpoint> {
        let threadId = config.threadId ?? THREAD_ID_DEFAULT()
            
        guard let result = self.checkpointsByThread[threadId] else {
            let result = Stack<Checkpoint>();
            self.checkpointsByThread[threadId] = result;
            return result;
        }
        return result

    }
    
    private func updateCheckpoint( config: RunnableConfig, checkpoints: Stack<Checkpoint>  ) {
        let threadId = config.threadId ?? THREAD_ID_DEFAULT()
        
        self.checkpointsByThread[threadId] = checkpoints
    }
    
    public func get(config: RunnableConfig) -> Checkpoint? {
        let checkpoints = checkpoints(config: config);
        
        guard let checkpointId = config.checkpointId else {
            return checkpoints.peek()
        }
        
        return checkpoints.first(where: { $0.id == checkpointId })
    }
    
    public func put(config: RunnableConfig, checkpoint: Checkpoint) throws -> RunnableConfig {
        var checkpoints = checkpoints(config: config);
        
        if let checkpointId = config.checkpointId {
            
            checkpoints[checkpointId] = checkpoint
        }
        
        checkpoints.push(checkpoint)
        
        updateCheckpoint( config: config, checkpoints: checkpoints )
        
        var result = config
        
        result.checkpointId = checkpoint.id
        
        return result
        
    }
    
    public func release(config: RunnableConfig) throws -> Tag {
        fatalError( "Not implemented" )
    }
    
    public func list(config: RunnableConfig) -> AnyCollection<Checkpoint> {
        let checkpoints = checkpoints(config: config);
        
        return AnyCollection(checkpoints.elements)
    }
}

