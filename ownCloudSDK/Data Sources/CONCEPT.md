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
- compositions
	- allow combining different data sources into a consolidated, "composed" data source
	- allow sorting and filtering through blocks, either on item references or item records
		- leveraging converters and presentable intermediates allows implementing filters and sorting that work across data types

- mapped
	- maps/converts a source datasource's items into other items and allows keeping them in sync with minimum effort

## Composition example
The following code shows examples for various customizations. NOTE: not all of the customizations shown make sense at the same time.

```swift
// Create a composed data source concating core.personalAndSharedDrivesDataSource and core.projectDrivesDataSource
let composedDataSource = OCDataSourceComposition(sources: [
	core.personalAndSharedDrivesDataSource,
	core.projectDrivesDataSource
], applyCustomizations: { (composedDataSource) in
	// Apply customizations before first assembly

	// Sort concated items
	composedDataSource.sortComparator = OCDataSourceComposition.itemComparator(withItemRetrieval: false, fromRecordComparator: { record1, record2 in
		var presentable1 : OCDataItemPresentable?
		var presentable2 : OCDataItemPresentable?

		if let item = record1?.item {
			presentable1 = OCDataRenderer.default.renderItem(item, asType: .presentable, error: nil) as? OCDataItemPresentable
		}

		if let item = record2?.item {
			presentable2 = OCDataRenderer.default.renderItem(item, asType: .presentable, error: nil) as? OCDataItemPresentable
		}

		let title1 = presentable1?.title ?? ""
		let title2 = presentable2?.title ?? ""

		return title1.localizedCompare(title2)
	})

	// Filter concated items (only items with a title starting with "A")
	composedDataSource.filter = OCDataSourceComposition.itemFilter(recordFilter: { record in
		if let item = record?.item,
		   let presentable = OCDataRenderer.default.renderItem(item, asType: .presentable, error: nil) as? OCDataItemPresentable,
		   let startsWithA = presentable.title?.starts(with: "A") {
			return startsWithA
		}

		return false
	})

	// Sort items inside core.projectDrivesDataSource by last character
	composedDataSource.setSortComparator(OCDataSourceComposition.itemComparator(withItemRetrieval: false, fromRecordComparator: { record1, record2 in
		var presentable1 : OCDataItemPresentable?
		var presentable2 : OCDataItemPresentable?

		if let item = record1?.item {
			presentable1 = OCDataRenderer.default.renderItem(item, asType: .presentable, error: nil) as? OCDataItemPresentable
		}

		if let item = record2?.item {
			presentable2 = OCDataRenderer.default.renderItem(item, asType: .presentable, error: nil) as? OCDataItemPresentable
		}

		let title1 = presentable1?.title?.last?.lowercased() ?? ""
		let title2 = presentable2?.title?.last?.lowercased() ?? ""

		return title1.localizedCompare(title2)
	}), for: core.projectDrivesDataSource)

	// Filter items inside core.projectDrivesDataSource (only items with a title starting with "A")
	composedDataSource.setFilter(OCDataSourceComposition.itemFilter(withItemRetrieval: false, fromRecordFilter: { (record) in
		if let item = record?.item,
		   let presentable = OCDataRenderer.default.renderItem(item, asType: .presentable, error: nil) as? OCDataItemPresentable,
		   let startsWithA = presentable.title?.starts(with: "A") {
			return startsWithA
		}

		return false
	}), for: core.projectDrivesDataSource)
})
```
