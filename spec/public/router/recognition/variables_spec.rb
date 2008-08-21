require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do
  
  describe "a route with variables in the path" do
    
    it "should create keys for each named variable" do
      Merb::Router.prepare { |r| r.match!("/:foo/:bar") }
      route_to("/one/two").should have_route(:foo => "one", :bar => "two")
    end
    
    it "should be able to match :controller, :action, and :id from the route" do
      Merb::Router.prepare { |r| r.match!("/:controller/:action/:id") }
      route_to("/foo/bar/baz").should have_route(:controller => "foo", :action => "bar", :id => "baz")
    end
    
    it "should be able to set :controller with #to" do
      Merb::Router.prepare { |r| r.match("/:action").to(:controller => "users") }
      route_to("/show").should have_route(:controller => "users", :action => "show")
    end
    
    it "should be able to combine multiple named variables into a param" do
      Merb::Router.prepare { |r| r.match("/:foo/:bar").to(:controller => ":foo/:bar") }
      route_to("/one/two").should have_route(:controller => "one/two", :foo => "one", :bar => "two")
    end
    
    it "should be able to overwrite matched named variables in the params" do
      Merb::Router.prepare { |r| r.match("/:foo/:bar").to(:foo => "foo", :bar => "bar") }
      route_to("/one/two").should have_route(:foo => "foo", :bar => "bar")
    end
    
    it "should be able to block named variables from being present in the params" do
      Merb::Router.prepare { |r| r.match("/:foo/:bar").to(:foo => nil, :bar => nil) }
      route_to("/one/two").should have_route(:foo => nil, :bar => nil)
    end
    
  end
  
  describe "a route with variables spread across match blocks" do
    
    it "should combine the path conditions from each match statement" do
      Merb::Router.prepare do |r|
        r.match("/:foo") { |f| f.match!("/:bar") }
      end
      route_to("/one/two").should have_route(:foo => "one", :bar => "two")
    end
  end
  
end