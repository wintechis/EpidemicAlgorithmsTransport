/**
* Name: ShopFloor_Grid
* Author: Sebastian Schmid
* Description: defines superclass for all species as well as the shop floor   
* Tags: 
*/

model ShopFloor_Grid

global {
	
	
	int cell_width;
	int cell_height <- cell_width; 
	
	int width <- 10;
	
	
	list<string> placement_mode const: true <- ["strict"];
		//describes the distribution mode for stations:
		/*strict:		4 stations making a square near the center   
		 */

	/*this variable is only needed when placement mode "centered" is chosen and defines the radius of the placement circle in the center */

	
	list<string> color_mode const:true <- ["unique"];  
	//describes the coloring mode for stations:
		/*unique: 		each color is only allowed once
		 */
	string selected_color_mode <- color_mode[0]; //default is 'unique'
	
	int disturbance_cycles <- 500#cycles; //all N cycles, we change the color of our stations	
	
	/* Investigation variables*/
		map<rgb, int> delivered <- []; //will be used to keep track of how many things of each color have been delivered. "keys" of this maps contains the list of station colors. also used in Statio init!!
		int total_delivered <- 0; //holds the total amount of delivered things 
		
		//the time it took to deliver the thing to any accepting station
		int time_to_deliver_SUM <- 0; //this variable holds the SUM of all delivery times for calculating the mean
		float mean_of_delivered_cycles <- 0.0; //holds the average amount of cycles it took to deliver a thing successfully

	init
	{
		//nothing to initialize		
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
	
	list<shop_floor> neighbors2 <- self neighbors_at 2;  
	//neighbors_at is pre-defined for grid agents, here with a distance of 2. Result dependes on the grid's topology
	
		
	 aspect info {
        draw string(name) size: 3 color: #grey;
        
    }
    
    aspect position {
        draw string(location) size: 0.5 color: #grey;
        
    }
}

