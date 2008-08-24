require File.join(File.dirname(__FILE__), '..', "spec_helper")

describe "When generating URLs," do
  
  describe "a resource collection route" do
    
    before(:each) do
      Merb::Router.prepare do |r|
        r.resources :users
      end
    end
    
    it "should provide an index route" do
      url(:users).should == "/users"
    end
    
    it "should provide a new route" do
      url(:new_user).should == "/users/new"
    end
    
    it "should provide a show route" do
      url(:user, :id => 1).should == "/users/1"
    end
    
    it "should provide an edit route" do
      url(:edit_user, :id => 1).should == "/users/1/edit"
    end
    
    it "should provide a delete route" do
      url(:delete_user, :id => 1).should == "/users/1/delete"
    end
    
    it "should be able to specify different keys than :id" do
      Merb::Router.prepare do |r|
        r.resources :users, :keys => [:account, :name]
      end
      
      url(:users).should    == "/users"
      url(:new_user).should == "/users/new"
      url(:user, :account => "github", :name => "foo").should          == "/users/github/foo"
      url(:edit_user, :account => "lighthouse", :name => "bar").should == "/users/lighthouse/bar/edit"
      url(:delete_user, :account => "hello", :name => "world").should  == "/users/hello/world/delete"
      # -- Bad --
      lambda { url(:user, :id => 1) }.should raise_error(Merb::Router::GenerationError)
    end
    
    it "should be able to specify the path of the resource" do
      Merb::Router.prepare do |r|
        r.resources :users, :path => "admins"
      end
      
      url(:users).should == "/admins"
    end
    
    it "should be able to prepend the name" do
      Merb::Router.prepare do |r|
        r.resources :users, :name_prefix => :admin
      end
      
      url(:admin_users).should == "/users"
      url(:new_admin_user).should == "/users/new"
      url(:admin_user, :id => 1).should == "/users/1"
      url(:edit_admin_user, :id => 1).should == "/users/1/edit"
      url(:delete_admin_user, :id => 1).should == "/users/1/delete"
    end
    
    it "should be able to add extra collection routes" do
      Merb::Router.prepare do |r|
        r.resources :users, :collection => {:hello => :get, :goodbye => :post}
      end
      
      url(:hello_users).should == "/users/hello"
      url(:goodbye_users).should == "/users/goodbye"
    end
    
    it "should be able to add extra member routes" do
      Merb::Router.prepare do |r|
        r.resources :users, :member => {:hello => :get, :goodbye => :post}
      end
      
      url(:hello_user, :id => 1).should   == "/users/1/hello"
      url(:goodbye_user, :id => 1).should == "/users/1/goodbye"
    end
    
    it "should be able to specify arbitrary sub routes" do
      Merb::Router.prepare do |r|
        r.resources :users do |u|
          u.match("/:foo", :foo => %r[^foo-\d+$]).to(:action => "foo").name(:foo)
        end
      end
      
      url(:user_foo, :user_id => 2, :foo => "foo-123").should == "/users/2/foo-123"
    end
    
  end
  
  describe "a resource object route" do
    
    before(:each) do
      Merb::Router.prepare do |r|
        r.resource :form
      end
    end
    
    it "should provide a show route" do
      url(:form).should == "/form"
    end
    
    it "should provide a new route" do
      url(:new_form).should == "/form/new"
    end
    
    it "should provide an edit route" do
      url(:edit_form).should == "/form/edit"
    end
    
    it "should provide a delete route" do
      url(:delete_form).should == "/form/delete"
    end
    
    it "should not provide an index route" do
      lambda { url(:forms) }.should raise_error(Merb::Router::GenerationError)
    end
    
    it "should be able to specify arbitrary sub routes" do
      Merb::Router.prepare do |r|
        r.resource :form do |u|
          u.match("/:foo", :foo => %r[^foo-\d+$]).to(:action => "foo").name(:foo)
        end
      end
      
      url(:form_foo, :foo => "foo-123").should == "/form/foo-123"
    end
    
  end
  
  describe "a nested resource route" do
    
    before(:each) do
      Merb::Router.prepare do |r|
        r.resources :users do |u|
          u.resources :comments
        end
      end
    end
    
    it "should provide an index route" do
      url(:user_comments, :user_id => 5).should == "/users/5/comments"
    end
    
    it "should provide a new route" do
      url(:new_user_comment, :user_id => 5).should == "/users/5/comments/new"
    end
    
    it "should provide a show route" do
      url(:user_comment, :user_id => 5, :id => 1).should == "/users/5/comments/1"
    end
    
    it "should provide an edit route" do
      url(:edit_user_comment, :user_id => 5, :id => 1).should == "/users/5/comments/1/edit"
    end
    
    it "should provide a delete route" do
      url(:delete_user_comment, :user_id => 5, :id => 1).should == "/users/5/comments/1/delete"
    end
    
  end
  
  describe "a resource route nested in a conditional block" do
    it "should use previously set conditions" do
      Merb::Router.prepare do |r|
        r.match("/prefix") do |p|
          p.resources :users
        end
      end
      
      url(:users).should == "/prefix/users"
    end
  end
end