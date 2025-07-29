import { ChakraProvider, Box, Heading, Text } from "@chakra-ui/react";
import { BrowserRouter as Router, Routes, Route} from "react-router-dom";
import QueryImage from "./QueryImage";
import ExistingItems from "./ExistingItems";
import RecentItems from "./RecentItems";

function App() {
  return (
    <ChakraProvider>
      <Router>
        <Box maxW="md" mx="auto" mt={10} p={6} borderWidth={1} borderRadius="lg" boxShadow="md">
          <Heading mb={4}>Part Finder</Heading>
          <Text mb={2}>Upload images, remove items, and query the database.</Text>
          <Routes>
            <Route path="/items" element={<ExistingItems />} />
            <Route path="/" element={
              <>
                <QueryImage />
                <RecentItems />
              </>
            } />
          </Routes>
        </Box>
      </Router>
    </ChakraProvider>
  );
}

export default App;
