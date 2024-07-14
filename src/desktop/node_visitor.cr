module Desktop
  abstract class NodeVisitor
    def visit(node : Node)
      node.children.each do |child|
        visit(child)
      end
    end

    def visit(node : LeafNode)
    end
  end
end
