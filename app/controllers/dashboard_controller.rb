require "net/http"
require "net/https"
require "rubygems"
require "json"
require 'open-uri'
require 'zip/zip' #NEW

class DashboardController < ApplicationController
  before_filter :authenticate_user!, :except => [:welcome]

  #replaced uploadToNew
  def uploadToAWS
  
    @len = session[:finished_list].length #1st time user, session[:finished_list] is [] DEBUG
    user_id = current_user.id
    #@user = current.user

    if request.post? #if the user clicked the "upload" button on the form
      if params[:album_name] == ""
        flash.now[:error] = "Please enter a new album name before uploading a picture."
      
      elsif params[:upload].nil? #a new album name is required
        flash.now[:error] = "Please choose a picture to upload." #show error msg is new album name is empty

      #first find if user already has album with that name
      elsif Album.find_by_name(params[:album_name]).nil?
      #if Album.find_by_name_and_user_id(params[:albumName], user_id)==nil

        #start create new album,new picture, and upload the file.
        if params[:album_name] and not params[:album_id]
          album = Album.create!(:name => params[:album_name], :user_id => user_id)
        else
          album = Album.find_by_id(params[:album_id])
        end
        #actually uploading photo
        #debugger
        new_photo = Picture.uploadToAWS(params[:upload], album)
        #debugger
        
        redirect_to :action => "selectPhoto", :album_id => album.id

      else #if user already has album with same name
        flash[:error] = "You already have an album named #{params[:album_name]}, enter a new album name or add to the existing one!"
        redirect_to :action => "uploadToAWS"
      end
    end
  end

  def welcome
  end

  def index  #displaying facebook albums
    session.delete(:tasks)
    session.delete(:results)

  #---------------------check notification---------------------------
    queryList = Query.find_all_by_user_id(current_user.id) #DEBUG: is it possible that the 1st time user's queryList is nil?
    pendingList = []
    finishedList = []
    
    queryList.each do |query|
      if query.result_link == ""
        #ask the api if the task is finished or not
        response = nil
        url = URI(query.task_link)
        http = Net::HTTP.new(url.host, 443)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.start do |http|
          req = Net::HTTP::Get.new(url.path)
          req.basic_auth('ethanph5','dxlf1314')
          response = http.request(req)
          #puts response.body
        end
        
        parsed_json = ActiveSupport::JSON.decode(response.body)

        #if answer = "sth" # finished, update Query table, add it to finishedlist
        if parsed_json["answer"] != ""
          finishedList << query.id
          answer = parsed_json["answer"]
          theEnd = answer.length 
          answer = answer[7...theEnd]
          query.result_link = "http://i." + answer + ".jpeg"
          query.save
        else #task not finished on api
          pendingList << query.id
        end
      else #if result_link already exists in db
        #dont ask the api, just add it to finished list, and do the counting
        finishedList << query.id
      end
    end
    @len = finishedList.length #for 1st time user, it is 0, finishedList is []; @len in other function will directly use session[:finished_list] to update the value
    #session[:lenFinish] = finishedList.length #DEBUG

    session[:finished_list] = finishedList #a list of query ids; 1st time user will be []
    session[:pending_list] = pendingList #a list of query ids; 1st time user will be []
#----------------------------check notification ends here------------


    if not session[:picture]
      session[:picture] = Hash.new
    end
    if params[:picture]       
      params[:picture].each do |key, value|
        session[:picture][key] = value
      end
    end
    @selected_picture = session[:picture]

    if not session[:picturefb]
      session[:picturefb] = Hash.new
    end  
    if params[:picturefb]
      params[:picturefb].each do |key, value|
        session[:picturefb][key] = value
      end
    end
    @selected_picturefb = session[:picturefb]

    
    # crowd albums part
    @crowdAlbums = User.find_by_id(current_user.id).albums

    # facebook albums part
    
    auth = Authorization.find_by_user_id(current_user.id)
    if auth
      token = auth.token
    end
    @user = current_user
    @user_name = current_user.name
    if token
      @albums = @user.grap_facebook_albums(token)
      #@albums = result
    else
      @albums = nil
    end
    @pictureSelected = Picture.find(@selected_picture.keys)
    @picturefbSelected = @selected_picturefb.keys
  end

  def showPhoto
    @len = session[:finished_list].length #DEBUG
    fb_album_id = params[:fb_album_id]
    token = Authorization.find_by_user_id(current_user.id).token
    albums = current_user.grap_facebook_albums(token)
    albums.each do |album|
      if album.identifier == fb_album_id
        @fb_pictures = album.photos
        @fb_album_name = album.name
      end
    end
  end

  def selectPhoto  #checkboxes page
    #album_id = params[:album_id]
    album = Album.find_by_id(params[:album_id])
    @album_name = album.name
    @pictures = album.pictures
    @len = session[:finished_list].length
  end


  def uploadPhotoToExisting     #upload photo to existing album
    @len = session[:finished_list].length
    user_id = current_user.id
    @user = User.find(user_id)

    if request.post? #if the user clicked the "upload" button on the form
      #start create new album,new picture, and upload the file.
      album_id = params[:album_id]

      #actually uploading photo
      namePathList = Picture.handleUpload(params[:upload], user_id)
      name = namePathList[0]
      path = namePathList[1]

      #create new picture tuple WARNING THIS MIGHT BE REDUNDANT CUZ OF ETHANS UPLOADTOAWS
      newPicture = Picture.create!(:name => name,:internal_link => path, :user_id => user_id, :album_id => album_id)

      redirect_to :action => "selectPhoto", :album_id => album_id

      #should reder somewhere at the end
    end
  end

  def selectAlbum
    @len = session[:finished_list].length
    user_id = current_user.id
    user = User.find(user_id)
    albumList = user.albums
    @lol = [] #@lol is [[al.name,al.id],[al.name,al.id]]
    albumList.each do |al|
      @lol << [al.name,al.id]
    end
  end

  def specifyTask

    @len = session[:finished_list].length

    if session[:picture] == {} and session[:picturefb] == {}
      flash[:error] = "Please Select Photo(s) Before Specifying Task(s)"
      redirect_to :action => :index
    end
    
    @selected_picture = session[:picture] || Hash.new
    #@selected_picturefb = session[:picturefb] || Hash.new
    if not session[:picturefb].empty?
      fb_user = current_user.fb_user 
      @selected_picturefb = Hash.new
      session[:picturefb].keys.each do |pid|
        @selected_picturefb[pid] = fb_picture_link(fb_user, pid)
      end
    else
      @selected_picturefb = Hash.new
    end
    @pictureSelected = Picture.find(@selected_picture.keys)
    #@picturefbSelected = @selected_picturefb.keys
    @picturefbSelected = @selected_picturefb
    @specify_task = session[:tasks] || Hash.new 
    @specify_result = session[:results] || Hash.new
    user_id = current_user.id
    @user_name = User.find(current_user.id).name
  end

  def reviewTask
    @len = session[:finished_list].length

    @selected_picture = session[:picture]
    #@selected_picturefb = session[:picturefb]
    if not session[:picturefb].empty?
      fb_user = current_user.fb_user
      @selected_picturefb = Hash.new
      session[:picturefb].keys.each do |pid|
        @selected_picturefb[pid] = fb_picture_link(fb_user, pid)
      end
    else
      @selected_picturefb = Hash.new
    end
    @pictureSelected = Picture.find(@selected_picture.keys)
    #@picturefbSelected = @selected_picturefb.keys
    @picturefbSelected = @selected_picturefb
    @specify_task = params[:tasks] || session[:tasks]
    session[:tasks] = @specify_task
    @specify_result = params[:results] || session[:results]
    session[:results] = @specify_result
    @user_name = User.find(current_user.id).name
  end

  def submit
    #@len = session[:lenFinish]
    #@selected_pictures = session[:picture] #hashTable: key is pic id, value is 1
    #@selected_picturesfb = session[:picturefb]
    #@taskTable = session[:tasks] #key is picture id, value is the task string
    #@resultTable = session[:results] #key is picture id, value is the # of result the user wants
    redirect_to :controller => :mobilework, :action => :submit_task
    #redirect_to :controller => :mobilework, :action => :submit_task, :picTable => @selected_pictures, :picfbTable => @selected_picturesfb, :taskTable => @taskTable, :resultTable => @resultTable
  end
  
  
  def fb_picture_link(fb_user, picture_id)
    albums = fb_user.albums
    albums.each do |album|
      album.photos.each do |photo|     
        if photo.identifier == picture_id
          return photo.source
        end
      end
    end
  end

  def getResult
    @len = session[:finished_list].length
    if params[:remaining_after_accept]
      @finished_list = params[:remaining_after_accept] 
      #debugger         
    elsif params[:remaining_after_reject]
      @finished_list = params[:remaining_after_reject]
    else #first time loading getResult page
      @finished_list = session[:finished_list]
      
    end
    #debugger
    @pending_list = session[:pending_list]
  end  
  
  def acceptResult
    accept_query_id = params[:accept_query].to_i #params[:accept_query] is a string
    
    #serve for download
    if session[:download] #DEBUG: not nil
      downloadList = session[:download] #downloadList is a list of accept_query_id
      downloadList << accept_query_id
      session[:download] = downloadList
      
    else #not accept one before
      session[:download] = [accept_query_id]
    
    end 
    
    #end of serve for download
    
    temp_finished_list = session[:finished_list]
    temp_finished_list.delete(accept_query_id)
    session[:finished_list] = temp_finished_list #stores int
    @len = session[:finished_list].length
    
    redirect_to :action => :getResult, :remaining_after_accept => temp_finished_list and return
    #debugger 
  end
  
  def rejectResult
    reject_query_id = params[:reject_query].to_i
    
    Query.destroy(reject_query_id) #DEBUG: id data type? need save! ?? Has performed action, remove from query table
    
    
    temp_finished_list = session[:finished_list]
    temp_finished_list.delete(reject_query_id)
    session[:finished_list] = temp_finished_list  #session[:finished_list] will actually update itself in index;do this to ensure the inbox number
                                                  #is correct if the user goes from getResult page to other pages like Uploadtoaws
    redirect_to :action => :getResult, :remaining_after_reject => temp_finished_list and return
    #debugger      
  end
  
  def download
    #-----------------------download------------------------------------
    if session[:download]  #there's something to download
      downloadList = session[:download] #a list of query ids, int type
      
      Zip::ZipFile.open("result.zip", Zip::ZipFile::CREATE) { |zipfile|  #DEBUG: it was my.zip, need to change
        
        downloadList.each do |qid|
          query = Query.find_by_id(qid)
          if query
            query.result_link =~ /.*(\/)(.*)/
            name = $2
            
            data = open(query.result_link).read
            
            #Query.destroy(qid)
         
            zipfile.get_output_stream("#{name}") { |f| f.puts data }
          end
        end
      }
      
      send_file("result.zip") #DEBUG: inside the block above?
      
      #----------- remove the server files ----------------
      Zip::ZipFile.open("result.zip", Zip::ZipFile::CREATE) { |zipfile|
          downloadList.each do |qid|
            query = Query.find_by_id(qid)
            if query
              query.result_link =~ /.*(\/)(.*)/
              name = $2
              Query.destroy(qid)
              zipfile.remove("#{name}")
            end
          end     
      }
      
      #-------------------end of removing server folders-----------
      
      session[:download] = nil #clear session[:download]!!!
    
    else #nothing to download
      flash[:error] = "Please accept one or more results before downloading; If there's no result, please wait for workers' response or submit new tasks."
      redirect_to :action => :getResult and return
    end  
    #---------------------end of download--------------------------------
  end
end

  
