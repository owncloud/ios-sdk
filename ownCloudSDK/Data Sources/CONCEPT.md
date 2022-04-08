#  Data Sources

## Concept / Objectives
- mechanism to provide data items in a structured way
	- supports updates
	- supports hierarchies
- optimized for low memory footprint
	- avoid duplication of data in memory
	- items can be implemented by protocol compliance
	- enclosing types are only used temporarily and in low numbers
- optimized for performance
	- multiple changes to the content within one runloop cycle trigger only a single update
- modular, pipeline-based rendering
	- converters
		- convert from an input to an output type, f.ex.
			- to convert an OCItem into a dictionary of [title, description, thumbnail, [icons]]
			- to convert that dictionary into an actual table/collection view cell
		- can be chained together
			- providing conversion from an input to an output type
		- performance / memory optimized
			- memory: converters don't save state, so can be used in multiple renderers
			- performance: options dictionary allows passing f.ex. existing cells for possible reuse
	- presentables
		- standardized intermediate representation
		- allows simplified display and conversion from many input to many output types
	- renderers
		- manage data sources
		- render items to the desired output type using converters / converter pipelines
		- can dynamically assemble new pipelines from a combination of existing converters / converter pipelines
		- cell configurations allow temporarily passing additional objects to cell renderers alongside item references, where it is otherwise not possible
