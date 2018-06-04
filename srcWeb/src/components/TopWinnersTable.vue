<template>
  <div class="winners">
    <span class="tableCaption">{{ tableData.caption }}</span>
    <div class=" table-container ">
      <table class="table " :data="tableData ">

        <tbody v-if="tableData.gridData.length> 0 && !tableData.isLoading">
          <tr>
            <th v-for=" column in tableData.gridColumns " class="columnName ">
              {{ column }}
            </th>
          </tr>

          <tr v-for="entry in tableData.gridData ">
            <td v-for="key in tableData.gridColumns " class="columnData ">
              {{ entry[key] }}
            </td>
          </tr>
        </tbody>

        <span v-else-if="!tableData.isLoading " class="error ">No records found</span>
        <span v-else v-loading="true " element-loading-text="Loading... "></span>

      </table>
    </div>
  </div>
</template>

<script>
  export default {
    props: ['tableData'],
    created() {},
  }

</script>
