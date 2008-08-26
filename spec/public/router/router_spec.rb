require File.join(File.dirname(__FILE__), "spec_helper")

describe Merb::Router do
  
  describe "#prepare" do
    
    before(:each) do
      @builder_methods = [
        :add, :match, :match!, :fixatable, :register,
        :name, :full_name, :to, :defaults, :options, :defer_to,
        :default_routes, :namespace, :redirect, :resources, :resource
      ]
    end
    
    it "should be able to compile an empty route table" do
      lambda do
        Merb::Router.prepare { }
      end.should_not raise_error(SyntaxError)
    end
    
    it "should yield an instance of the builder object" do
      Merb::Router.prepare do |r|
        @builder_methods.each do |method|
          r.should respond_to(method)
        end
      end
    end
    
    it "should evaluate the prepare block in context of an object that can proxy method calls to the current builder object" do
      pending
      Merb::Router.prepare do
        @builder_methods.each do |method|
          self.should respond_to(method)
        end
      end
    end
    
    it "should be able to keep track of the current builder context when calling to" do
      pending
      Merb::Router.prepare do
        match("/hello") do
          match("/world").to(:controller => "hellos")
        end
      end
      
      route_to("/hello/world").should have_route(:controller => "hello")
    end
    
    it "should be able to keep track of the current builder context when calling to" do
      pending
      Merb::Router.prepare do
        match("/hello") do
          to(:controller => "hellos")
        end
      end
      
      route_to("/hello").should have_route(:controller => "hellos")
    end
  end

  describe "#match" do
    
    it "should raise an error if the routes were not compiled yet" do
      lambda { Merb::Router.match(simple_request) }.should raise_error(Merb::Router::NotCompiledError)
    end
    
    it "should choose the correct route when multiple routes are defined" do
       Merb::Router.prepare  do |r| 
         r.match("/denver").to(:controller => "one")
         r.match("/houston").to(:controller => "two")
       end
       
       route_to("/denver").should have_route(:controller => "one")
       route_to("/houston").should_not have_route(:controller => "one")
    end
  end

end