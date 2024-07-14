require "../spec_helper"

describe Desktop::Widget do
  before_each do
    Desktop::Item.reset_item_ids
    Desktop::LeafNode.reset_item_ids
  end

  it "rotates items in a single node" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 3)
    desktop.print_list.should eq("LeafNode1 {Item3,Item2,Item1,}➜Nil")
    desktop.switcher.rotate
    desktop.set_current_item(desktop.switcher.stop.not_nil!)
    desktop.print_list.should eq("LeafNode1 {Item2,Item3,Item1,}➜Nil")
    desktop.switcher.rotate
    desktop.switcher.rotate
    desktop.set_current_item(desktop.switcher.stop.not_nil!)
    desktop.print_list.should eq("LeafNode1 {Item1,Item2,Item3,}➜Nil")
  end

  it "rotates nodes" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 4)
    desktop.move(:right)
    desktop.focus(:left)
    desktop.move(:right)
    desktop.move(:right)

    desktop.print_list.should eq("LeafNode2 {Item3,Item4,}➜LeafNode1 {Item2,Item1,}➜Nil")
    desktop.switcher.rotate
    desktop.set_current_item(desktop.switcher.stop.not_nil!)
    desktop.print_list.should eq("LeafNode2 {Item4,Item3,}➜LeafNode1 {Item2,Item1,}➜Nil")
    desktop.switcher.rotate
    desktop.switcher.rotate
    desktop.set_current_item(desktop.switcher.stop.not_nil!)
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜LeafNode2 {Item4,Item3,}➜Nil")
    desktop.switcher.rotate
    desktop.switcher.rotate
    desktop.switcher.rotate
    desktop.set_current_item(desktop.switcher.stop.not_nil!)
    desktop.print_list.should eq("LeafNode2 {Item3,Item4,}➜LeafNode1 {Item2,Item1,}➜Nil")
  end
end
