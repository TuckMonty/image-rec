import React, { useEffect, useState } from "react";
import { Box, Heading, Text, Image, VStack, Spinner, Button, useDisclosure, useToast, Link as ChakraLink } from "@chakra-ui/react";
import { useParams, useNavigate, Link as RouterLink } from "react-router-dom";
import ImageUploadInput from "./ImageUploadInput";
import ViewImagesModal from "./ViewImagesModal";
import AddItemModal from "./AddItemModal";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

function ItemList() {
  const { itemId } = useParams();
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedItem, setSelectedItem] = useState(null);
  const [viewImagesItem, setViewImagesItem] = useState(null);
  const [viewImages, setViewImages] = useState([]);
  const [viewImagesLoading, setViewImagesLoading] = useState(false);
  const { isOpen: isAddOpen, onOpen: onAddOpen, onClose: onAddClose } = useDisclosure();
  const { isOpen: isViewOpen, onOpen: onViewOpen, onClose } = useDisclosure();
  const [files, setFiles] = useState([]);
  const [filePreviews, setFilePreviews] = useState([]);
  const toast = useToast();

  // Clean up object URLs when files change
  useEffect(() => {
    return () => {
      filePreviews.forEach(url => URL.revokeObjectURL(url));
    };
  }, [filePreviews]);

  // Reset files and previews when modal closes
  const onViewClose = () => {
    setFiles([]);
    setFilePreviews([]);
    if (typeof onClose === 'function') onClose();
    navigate('/');
  };

  // Ensure files and previews are cleared after upload as well
  useEffect(() => {
    if (files.length === 0 && filePreviews.length !== 0) {
      setFilePreviews([]);
    }
  }, [files]);

  useEffect(() => {
    async function fetchItems() {
      try {
        const res = await axios.get(`${API_URL}/items/`);
        debugger
        setItems(res.data.items);
      } catch (err) {
        setItems([]);
      } finally {
        setLoading(false);
      }
    }
    fetchItems();
  }, []);

  const handleOpenModal = (item) => {
    setSelectedItem(item);
    setFiles([]);
    onAddOpen();
  };

  const handleUpload = async () => {
    const item = viewImagesItem || selectedItem;
    if (!item || files.length === 0) {
      toast({ title: "Please select images.", status: "warning" });
      return;
    }
    try {
      for (let file of files) {
        const formData = new FormData();
        formData.append("item_id", item.item_id);
        formData.append("file", file);
        await axios.post(`${API_URL}/upload/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      }
      toast({ title: "Images added!", status: "success" });
      setFiles([]);
      setFilePreviews([]);
      // Optionally refresh images after upload
      if (viewImagesItem) {
        handleViewImages(item);
      }
    } catch (err) {
      toast({ title: "Upload failed.", status: "error" });
    }
  };

  // Remove item and all its images
  const handleRemoveItem = async (itemId) => {
    if (!itemId) return;
    try {
      await axios.delete(`${API_URL}/item/${itemId}`);
      toast({ title: "Item removed!", status: "success" });
      setViewImagesItem(null);
      setViewImages([]);
      setFiles([]);
      setFilePreviews([]);
      // Refresh items list
      const res = await axios.get(`${API_URL}/items/`);
      setItems(res.data.items);
      onViewClose();
    } catch {
      toast({ title: "Failed to remove item.", status: "error" });
    }
  };

  // Add new item and open its view image modal
  const handleAddItem = async ({ itemId, itemName }) => {
    try {
      const nameToUse = itemName.trim() === "" ? itemId : itemName;
    //   const res = await axios.post(`${API_URL}/item/`, { item_id: itemId, item_name: nameToUse });
    //   const newItem = res.data.item;
      // Refresh items list
      const itemsRes = await axios.get(`${API_URL}/items/`);
      setItems(itemsRes.data.items);
      onAddClose();
      // Redirect to open modal for new item
      navigate(`/item/${itemId}`);
    } catch {
      toast({ title: "Failed to add item.", status: "error" });
    }
  };

  const handleViewImages = async (item) => {
    setViewImagesItem(item);
    setViewImagesLoading(true);
    try {
      const res = await axios.get(`${API_URL}/item_images/${item.item_id}`);
      setViewImages(res.data.images);
    } catch {
      setViewImages([]);
    } finally {
      setViewImagesLoading(false);
      onViewOpen();
      navigate(`/item/${item.item_id}`);
    }
  };

  const handleDeleteImage = async (img) => {
    if (!viewImagesItem) return;
    // Extract just the filename from the image URL
    let filename = img;
    try {
      // If img is a URL, extract the last segment after '/'
      if (typeof img === 'string' && img.includes('/')) {
        filename = img.split('/').pop().split('?')[0];
      }
      await axios.delete(`${API_URL}/item_image/${viewImagesItem.item_id}/${filename}`);
      setViewImages(viewImages.filter(i => i !== img));
      toast({ title: "Image deleted!", status: "success" });
    } catch {
      toast({ title: "Delete failed.", status: "error" });
    }
  };

  // Open modal if route has itemId param
  useEffect(() => {
    if (itemId && items.length > 0) {
      const found = items.find(i => i.item_id === itemId);
      if (found) {
        (async () => {
          await handleViewImages(found);
        })();
      }
    }
    // eslint-disable-next-line
  }, [itemId, items]);

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <Heading size="md" mb={2}>Existing Items</Heading>
      {loading ? <Spinner /> : (
        <VStack align="start" spacing={4}>
          {items.map(item => (
            <Box
              key={item.item_id}
              display="flex"
              alignItems="center"
              width="100%"
              cursor="pointer"
              _hover={{ bg: "gray.50" }}
              onClick={() => handleViewImages(item)}
              px={2}
              py={1}
            >
              <Image src={item.preview_image} boxSize="60px" objectFit="cover" mr={3} borderRadius="md" />
              <Box flex="1">
                <Text fontWeight="bold">{item.item_name}</Text>
                <Text fontSize="sm" color="gray.500">ID: {item.item_id}</Text>
              </Box>
              <ChakraLink as={RouterLink} to={`/item/${item.item_id}`} ml={2} onClick={e => e.stopPropagation()}>
                <Button
                  size="sm"
                  colorScheme="teal"
                >View Images</Button>
              </ChakraLink>
            </Box>
          ))}
          {items.length === 0 && <Text>No items found.</Text>}
        </VStack>
      )}
      <ViewImagesModal
        isOpen={isViewOpen}
        onClose={onViewClose}
        item={viewImagesItem}
        images={viewImages}
        imagesLoading={viewImagesLoading}
        onDeleteImage={handleDeleteImage}
        files={files}
        setFiles={setFiles}
        filePreviews={filePreviews}
        setFilePreviews={setFilePreviews}
        onUpload={handleUpload}
        onRemoveItem={handleRemoveItem}
      />
      <AddItemModal onAddItem={handleAddItem} />
    </Box>
  );
}
export default ItemList;
