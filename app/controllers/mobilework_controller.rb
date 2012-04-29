require "net/http"
require "net/https"
require "rubygems"
require "json"

class MobileworkController < ApplicationController
  def submit_task
    counter = 0
    
    if params[:picTable] != nil
      picTable = params[:picTable] #picTable: key is pic id(string), value is 1
      picIDlist = picTable.keys #unfortunately, ids are string, not integer
    end

    if params[:picfbTable] != nil    
      picfbTable = params[:picfbTable]
      picfblist = picfbTable.keys
    end
    
    taskTable = params[:taskTable] #key is picture id, value is the task string
    resultTable = params[:resultTable] #key is picture id, value is the # of result the user wants
    
    submission_notice = []
    submission_error = []
    
    if params[:picTable] != nil
      picIDlist.each do |id|
        intID = id.to_i
        task = taskTable[id]
        numResult = resultTable[id] 
        question = task + " I want " + numResult + " different versions. Thank you!"
         
        internal_link = Picture.find(intID).internal_link #resource location
    
    
        url = URI("https://sandbox.mobileworks.com/api/v1/tasks/")
        http = Net::HTTP.new(url.host, 443)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.start {|http|
          headers = {"Content-Type" => "application/json"}
          req = Net::HTTP::Post.new(url.path, headers)
          req.basic_auth('FelixXie','Phoenix1218118')
          query = {
            "question" => question,
            "resource" => internal_link,
            "answerType" => "t"
          }
          req.body = query.to_json()
          response = http.request(req)

          if response.code == "201"
            submission_notice << "The task for #{Picture.find(intID).name} has been submitted successfully." 
            session.delete(:picture) #clear session[picture] here
            newResponse = response["location"] + "?format=json/"
            #puts response["location"] #response["location"] is http://sandbox.mobileworks.com/api/v1/tasks/229/
            Query.create!(:user_id => current_user.id, :task_link => newResponse, :result_link => "")
          
          else
            submission_error << "Sorry! The task for #{Picture.find(intID).name} has NOT been submitted successfully. Please try again!"   
            #puts "Error. Response code: " + response.code
          end
        }
      end
    end
    
    
    #-------------------------------------- facebook part ----------------------------
    if params[:picfbTable] != nil
      picfblist.each do |id|
        counter = counter + 1
        task = taskTable[id]
        numResult = resultTable[id] 
        question = task + " I want " + numResult + " different versions. Thank you!"
         
        internal_link = id #resource location
    
    
        url = URI("https://sandbox.mobileworks.com/api/v1/tasks/")
        http = Net::HTTP.new(url.host, 443)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.start {|http|
          headers = {"Content-Type" => "application/json"}
          req = Net::HTTP::Post.new(url.path, headers)
          req.basic_auth('FelixXie','Phoenix1218118')
          query = {
            "question" => question,
            "resource" => internal_link,
            "answerType" => "t"
          }
          req.body = query.to_json()
          response = http.request(req)    
          
          if response.code == "201"
            submission_notice << "The task for photo Facebook #{counter} has been submitted successfully." 
            session.delete(:picturefb) #clear session[picture] here
            newResponse = response["location"] + "?format=json/"
            #puts response["location"] #response["location"] is http://sandbox.mobileworks.com/api/v1/tasks/229/
            Query.create!(:user_id => current_user.id, :task_link => newResponse, :result_link => "")
            
          else
            submission_error << "Sorry! The task for photo Facebook #{counter} has NOT been submitted successfully. Please try again!"   
            #puts "Error. Response code: " + response.code
          end
        }
      end
    end
    
    #notice = "YOu have the following tasks: "
    #Query.find_all_by_user_id(current_user.id).each do |query|
     # notice << query.task_link
    #end
    #flash[:notice] = notice
    
    redirect_to :controller => :dashboard, :action => :index, :submission_notice => submission_notice, :submission_error => submission_error and return
  end  
end
