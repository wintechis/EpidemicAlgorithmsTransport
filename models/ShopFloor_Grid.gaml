/**
* Name: superstuff
* Model_Based_VS_SRA_Stigmergy
* Author: Sebastian Schmid
* Description: defines superclass for all species as well as the shop floor   
* Tags: 
*/

model ShopFloor_Grid

global {
	
	
	int cell_width;
	int cell_height <- cell_width; 
	
	int width <- 10;
	
	
	list<string> placement_mode const: true <- ["strict" , "random", "centered", "corners"];
		//describes the distribution mode for stations:
		/*strict:		4 stations making a square near the center  
		 *random: 		picks a random spot to place a station
		 *structured:	stations are placed in a symmetrical distance around the world center
		 *corners: 		stations are placed towards the world corners, but there also randomly  
		 */

	/*this variable is only needed when placement mode "centered" is chosen and defines the radius of the placement circle in the center */

	
	list<string> color_mode const:true <- ["unique", "random"];  
	//describes the coloring mode for stations:
		/*unique: 		each color is only allowed once
		 *random:		colors are picked randomly and can therefor occure more than once
		 */
	string selected_color_mode <- color_mode[0]; //default is 'unique'
	
	int disturbance_cycles <- 500#cycles; //in strict mode: all N cycles, we change the color of our stations	
	
	bool stigmergy_activated <- true; //flag for switching stigmergy on and off

	bool activate_negative_stigmergy <- false;
	/*I define the color of the thing as maximum (= 1.0) s.t. all other gradient have to lie below that. To make them distinguishable, the STRONG mark may have (color_gradient_max )*THING_COLOR. All other WEAK gradients are below. */
	float color_gradient_max <- 0.75 max: 0.99;
	
	
	/* Investigation variables - PART I (other part is places behind init block)*/
		map<rgb, int> delivered <- []; //will be used to keep track of how many things of each color have been delivered. "keys" of this maps contains the list of station colors. also used in Statio init!!
		int total_delivered <- 0; //holds the total amount of delivered things 
		
		//the time it took to deliver the thing to any accepting station
		int time_to_deliver_SUM <- 0; //this variable holds the SUM of all delivery times for calculating the mean
		float mean_of_delivered_cycles <- 0.0; //holds the average amount of cycles it took to deliver a thing successfully

	
	init
	{
		//nothin to initialize		
	}
}

species superclass schedules:[] {
	shop_floor my_cell <- one_of(shop_floor);
	
	init{
		location <- my_cell.location;	
	}
}

//grid shop_floor cell_width: cell_width cell_height: cell_height neighbors: 8 use_individual_shapes: false use_regular_agents: false {
grid shop_floor width: width height: width neighbors: 8 use_individual_shapes: false use_regular_agents: false { 	
 	
	//width: shop_floor_diameter height: shop_floor_diameter cannot be set, because the cell widht/height is set
	//the amount of cells hence depends on the environment
	//definition of a grid agent, here as shop floor cell agent with respective topology
	
	//TODO: removed (commented) all reflexes and variables for STIGMERGY behaviour, as we don't use them in this setting 
	 
	/////rgb color <- #white;// color is only used to display the colors. for recognition use colors_marks 
	/////map<rgb,float> color_marks <- nil; //holds the color marks and is used for recognition of marks
	/////bool changed <- false; //inidcates that something has been added or changed and initialised blending of colors again
	
	list<shop_floor> neighbors2 <- self neighbors_at 2;  
	//neighbors_at is pre-defined for grid agents, here with a distance of 2. Result dependes on the grid's topology
	
	//reset color
	/* 
	reflex when: empty(color_marks){
		color <- #white;
	}*/

	//color blender for display
	/* 
	reflex when: ((length(color_marks) >= 1) and changed){
		//operates the following way: first(color_marks.keys) gets the first rgb value and first(color_marks) the associate strength, which modifies the alpha channel gives blended_color its first value 		
		//displays all colors
		
		rgb blended_color <- first(color_marks.keys); //variable to mix colors. There is at least one color mark
		blended_color <-rgb(blended_color.red * first(color_marks.values), blended_color.green * first(color_marks.values), blended_color.blue * first(color_marks.values));
		
		if(length(color_marks) > 1){
			
			list<rgb> colors_ <- color_marks.keys;
			list<float> strengths <- color_marks.values;
				
			loop i from: 1 to: length(colors_)-1 { //REMARK: We skip the first value ON PURPOSE, because it is already included in blended_color!!
								
				blended_color <- blend(blended_color, rgb(colors_[i].red*strengths[i], colors_[i].green*strengths[i], colors_[i].blue*strengths[i])); //mix colors by taking each channel and manipulating the strength w.r.t. factor 
			}
		}
		
		color <- blended_color; //display
		changed <- false;
	}*/
	

	list<shop_floor> neighbors_with_distance(int distance){
		//if distance is one, naturally i am only my own neighbor
		return (distance >= 1) ? self neighbors_at distance : (list<shop_floor>(self));
	} 
	
	//adds a new color to the color mark container
	/* 
	action add_color_mark(rgb new_color, float strength){
					
		add strength at:new_color to: color_marks;
		changed <- true;
	}

	//deletes a color from the color mark container
	action delete_color_mark (rgb del_color){
		
		if(del_color in color_marks)
		{
			remove key: del_color from: color_marks;
			changed <- true;
		}
		
	}
	
	map<rgb,float> get_color_marks{
		return color_marks;
	}
	
	action set_color_marks(map<rgb,float> new_color_marks){
		color_marks <- new_color_marks; //override color marks with new values
		changed <- true;
	}
	
	float get_color_strength(rgb col)
	{	
		return (color_marks at col);
	}
	*/
	
	 aspect info {
        /////draw string(name) + " - " + string(color_marks at #red with_precision 5) size: 3 color: #grey;
        draw string(name) size: 3 color: #grey;
        
    }
    
    aspect position {
        draw string(location) size: 0.5 color: #grey;
        
    }
}

