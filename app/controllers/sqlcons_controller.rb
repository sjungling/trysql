class SqlconsController < ApplicationController
  #qvarname means it has to do with query

  # GET /sqlcons
  # GET /sqlcons.json
  def index
	#define session variables to load correct tutorial views
	session[:tutch] = 1
    session[:tutsec] = 1  
	session[:maxsec] = 7	
	session[:maxch] = 2	
	session[:uid] = 1 
	#Insert data into database
	respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sqlcons }
    end
  end

  #Returns users query into controller from view
  #@qstring = the query passed through params
  def fetchquery
	#Save initial query so user doesn't see uid regulation	
	@qstring_init = params[:q].downcase 
	@qstring = @qstring_init
	#Pull back regexp for the specific lesson
	sectionregex = Sqlcons.where(:ch => session[:tutch], :sec => session[:tutsec]).pluck(:regtext)
	@qmodel = Sqlcons.new(:id => 1, :qtext=> @qstring, :regtext => sectionregex[0])


	#Validate whether the query is valid
	if @qmodel.checkquery
	  #Call method to execute query
	  execquery	
	else
	  @qstatus = 2
	end

	#call method determining which errors to display, if any
	pickdisplay  
	render :show 
  end

  #Executes a given query against the chosen database
  def execquery
	@qstatus = 0

	#Fetch query results, rescue from any mysql exceptions
	begin
	  @qstring = append_query(@qstring) 
	  query = Dbq.new(:qtext=> @qstring)
	  @qresults = query.execquery
	rescue Exception => e
	  #use replace function to clean up error
	  msg = e.message.gsub /'/, ''
	  msg = msg.gsub /Mysql2::Error:(.*?)(:)(.*)/, '\1'
	  errquery = "select '"+ msg + "' as errormsg"
	  @qresults = ActiveRecord::Base.connection.execute(errquery)
	  #sql syntax exception key
	  @qstatus = 1
	end
	
  end

  #Used to control which rows a user can see. (Associated with their user id)
  def append_query(p_qstring)
	  
	  uid = current_user.id.to_s
	  tabname = p_qstring[/(from)( )*([_a-z]+)( )*([_a-z]*)/, 3]
	  tabalias = p_qstring[/(from)( )*([_a-z]+)( )*([_a-z]*)/, 5]
	  if tabalias.length > 0 && tabalias != 'join'
		where_clause = ' where '+ tabalias + '.uid = ' + uid
	  else	
		where_clause = ' where '+ tabname + '.uid = ' + uid
	  end
	  #We have to modify where we place 'where_clause' based on the incoming 
	  # SQL statment. Otherwise we create a syntax error
	  if p_qstring =~ /(where)/
		ret_string = p_qstring.gsub /(where)/, where_clause + ' and '
	  elsif p_qstring =~ /(group)/
		ret_string = p_qstring.gsub /(group)/, where_clause + ' group '
	  elsif p_qstring =~ /(order)/
		ret_string = p_qstring.gsub /(order)/, where_clause + ' order '
	  else
		ret_string = p_qstring + where_clause 
	  end
	  return ret_string
  end

  def nextlesson
	#Checks to see if user desired increment
	  #Would like to change the value of those params.
	if session[:tutsec] < session[:maxsec]
	  session[:tutsec] += 1
	elsif params[:nextch] == "nextch" && session[:tutch] < session[:maxch]
	  session[:tutch] += 1
	  session[:tutsec] = 1
	end
	@qstatus = 3 
	@qresults = nil
	pickdisplay
	render :show
  end
  
  #Based on current state of @qstatus, determines whether to 
  #display next stage in tutorial, or a specific error page
  def pickdisplay
	#successful query or incrementing section
	tutname = "tut" + session[:tutch].to_s + "-" + session[:tutsec].to_s + ".html"
	#mysqlerror
	if @qstatus == 1
	  errname = "sqlerror.html"	
	#not good query for lesson
	else
	  errname = "qerror.html"
	end
	#bool to determine views display
	@waserror = @qstatus != 0 && @qstatus != 3 
	path = "/home/nate/public/trysql/app/views/sqlcons/tutorials/"
	@lesson_name = path + tutname 
	@error_name = path + errname
  end


end
